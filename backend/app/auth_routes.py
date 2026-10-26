"""Authentication API endpoints: Register, Login, Refresh, Logout, Password Reset, Verification, Policy."""
from __future__ import annotations

import logging
import secrets
from datetime import timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from . import auth, mailer, settings_store as store
from .db import get_db
from .models import User, utcnow
from .security import get_current_user

log = logging.getLogger("auth_routes")

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


# ---------------------------------------------------------------- Schemas
class RegisterIn(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None


class LoginIn(BaseModel):
    username_or_email: str
    password: str
    remember_me: bool = False


class RefreshIn(BaseModel):
    refresh_token: str


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str


class ForgotPasswordIn(BaseModel):
    email: str


class ResetPasswordIn(BaseModel):
    email: str
    token: str
    new_password: str


class VerifyEmailIn(BaseModel):
    code: str


def _user_dict(u: User) -> dict[str, Any]:
    return {
        "id": u.id,
        "username": u.username,
        "email": u.email,
        "role": u.role,
        "is_active": u.is_active,
        "is_verified": u.is_verified,
        "created_at": u.created_at.isoformat() if u.created_at else None,
        "last_login_at": u.last_login_at.isoformat() if u.last_login_at else None,
    }


# ---------------------------------------------------------------- Routes
@router.get("/status")
def auth_status(db: Session = Depends(get_db)) -> dict[str, Any]:
    user_count = db.scalar(select(User.id).limit(1))
    return {
        "has_users": user_count is not None,
        "registration_enabled": True,
        "policy": auth.get_password_policy(),
    }


@router.get("/policy")
def get_policy() -> dict[str, Any]:
    return auth.get_password_policy()


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterIn, request: Request, db: Session = Depends(get_db)) -> dict[str, Any]:
    username = body.username.strip().lower()
    email = body.email.strip().lower()

    # 1. Check uniqueness
    existing = db.scalar(select(User).where(or_(User.username == username, User.email == email)))
    if existing:
        if existing.username == username:
            raise HTTPException(status.HTTP_409_CONFLICT, "Username is already taken")
        raise HTTPException(status.HTTP_409_CONFLICT, "Email is already registered")

    # 2. Check password against configurable policy
    try:
        auth.validate_password_policy(body.password)
    except auth.PasswordPolicyError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))

    # 3. First user gets admin role
    is_first_user = db.scalar(select(User.id).limit(1)) is None
    user_role = "admin" if is_first_user else "user"

    # 4. Generate email verification code (6-digit)
    verif_code = f"{secrets.randbelow(900000) + 100000}"
    verif_exp = utcnow() + timedelta(minutes=30)

    user = User(
        username=username,
        email=email,
        password_hash=auth.hash_password(body.password),
        role=user_role,
        is_active=True,
        is_verified=False,
        verification_code=verif_code,
        verification_code_expires_at=verif_exp,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if body.full_name and body.full_name.strip():
        store.put("full_name", body.full_name.strip())

    # Try sending email verification if mailer is configured
    try:
        if store.get("gmail_address") and store.get("gmail_app_password"):
            mailer.send_email(
                to_addr=user.email,
                subject="akremjobhunter - Email Verification Code",
                body_text=f"Welcome to akremjobhunter.\n\nYour 6-digit verification code is: {verif_code}\n\nThis code expires in 30 minutes.",
            )
    except Exception as exc:
        log.warning(f"Could not send email verification: {exc}")

    user_agent = request.headers.get("user-agent")
    ip = request.client.host if request.client else "unknown"
    tokens = auth.create_tokens(db, user, remember_me=False, user_agent=user_agent, ip_address=ip)

    return {
        "user": _user_dict(user),
        "tokens": tokens,
        "message": "Account created successfully. Please verify your email.",
    }


@router.post("/login")
def login(body: LoginIn, request: Request, db: Session = Depends(get_db)) -> dict[str, Any]:
    query = body.username_or_email.strip().lower()
    user = db.scalar(select(User).where(or_(User.username == query, User.email == query)))

    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")

    # Check lockout
    auth.check_account_locked(user)

    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Account has been deactivated")

    if not auth.verify_password(body.password, user.password_hash):
        auth.record_login_attempt(db, user, success=False)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")

    auth.record_login_attempt(db, user, success=True)

    user_agent = request.headers.get("user-agent")
    ip = request.client.host if request.client else "unknown"
    tokens = auth.create_tokens(db, user, remember_me=body.remember_me, user_agent=user_agent, ip_address=ip)

    return {
        "user": _user_dict(user),
        "tokens": tokens,
    }


@router.post("/refresh")
def refresh_token(body: RefreshIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    return auth.refresh_access_token(db, body.refresh_token)


@router.post("/logout")
def logout(body: RefreshIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    ok = auth.revoke_session(db, body.refresh_token)
    return {"ok": ok, "message": "Session revoked"}


@router.get("/me")
def get_me(user: User = Depends(get_current_user)) -> dict[str, Any]:
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    return _user_dict(user)


@router.post("/change-password")
def change_password(
    body: ChangePasswordIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")

    if not auth.verify_password(body.current_password, user.password_hash):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Current password is incorrect")

    try:
        auth.validate_password_policy(body.new_password)
    except auth.PasswordPolicyError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))

    user.password_hash = auth.hash_password(body.new_password)
    db.commit()
    return {"message": "Password changed successfully"}


@router.post("/forgot-password")
def forgot_password(body: ForgotPasswordIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    email = body.email.strip().lower()
    user = db.scalar(select(User).where(User.email == email))

    if user:
        token = secrets.token_hex(24)
        user.reset_token = token
        user.reset_token_expires_at = utcnow() + timedelta(minutes=30)
        db.commit()

        try:
            if store.get("gmail_address") and store.get("gmail_app_password"):
                mailer.send_email(
                    to_addr=user.email,
                    subject="akremjobhunter - Password Reset Token",
                    body_text=(
                        f"A password reset request was made for your akremjobhunter account.\n\n"
                        f"Your reset token is:\n{token}\n\n"
                        f"This token is valid for 30 minutes.\n"
                        f"If you did not request this, please ignore this email."
                    ),
                )
        except Exception as exc:
            log.warning(f"Failed to send password reset email: {exc}")

    # Always return 200 to prevent email enumeration
    return {"message": "If this email is registered, password reset instructions have been sent."}


@router.post("/reset-password")
def reset_password(body: ResetPasswordIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    email = body.email.strip().lower()
    user = db.scalar(select(User).where(User.email == email))

    if not user or not user.reset_token or user.reset_token != body.token:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired reset token")

    if user.reset_token_expires_at and user.reset_token_expires_at < utcnow():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Reset token has expired")

    try:
        auth.validate_password_policy(body.new_password)
    except auth.PasswordPolicyError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))

    user.password_hash = auth.hash_password(body.new_password)
    user.reset_token = None
    user.reset_token_expires_at = None
    user.failed_login_attempts = 0
    user.locked_until = None
    db.commit()

    return {"message": "Password has been reset successfully. You can now log in."}


@router.post("/verify-email")
def verify_email(
    body: VerifyEmailIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")

    code = body.code.strip()
    if not user.verification_code or user.verification_code != code:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid verification code")

    if user.verification_code_expires_at and user.verification_code_expires_at < utcnow():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Verification code has expired")

    user.is_verified = True
    user.verification_code = None
    user.verification_code_expires_at = None
    db.commit()

    return {"message": "Email verified successfully", "is_verified": True}


@router.post("/resend-verification")
def resend_verification(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")

    if user.is_verified:
        return {"message": "Email is already verified"}

    verif_code = f"{secrets.randbelow(900000) + 100000}"
    user.verification_code = verif_code
    user.verification_code_expires_at = utcnow() + timedelta(minutes=15)
    db.commit()

    try:
        if store.get("gmail_address") and store.get("gmail_app_password"):
            mailer.send_email(
                to_addr=user.email,
                subject="akremjobhunter - Email Verification Code",
                body_text=f"Your new verification code is: {verif_code}\n\nValid for 15 minutes.",
            )
    except Exception as exc:
        log.warning(f"Could not send email verification: {exc}")

    return {"message": "Verification code resent"}
