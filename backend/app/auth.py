"""Authentication service: Argon2id hashing, RFC 7519 JWT tokens, configurable password policy, lockout protection."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import os
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from cryptography.exceptions import InvalidKey
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
from fastapi import HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .config import get_settings
from .models import User, UserSession, utcnow
from . import settings_store as store

log = logging.getLogger("auth")


# ---------------------------------------------------------------- Password Policy
class PasswordPolicyError(Exception):
    pass


def get_password_policy() -> dict[str, Any]:
    return {
        "min_length": int(store.get("auth_min_password_length") or 8),
        "require_uppercase": bool(store.get("auth_require_uppercase") if store.get("auth_require_uppercase") is not None else True),
        "require_lowercase": bool(store.get("auth_require_lowercase") if store.get("auth_require_lowercase") is not None else True),
        "require_numbers": bool(store.get("auth_require_numbers") if store.get("auth_require_numbers") is not None else True),
        "require_special": bool(store.get("auth_require_special") if store.get("auth_require_special") is not None else False),
        "max_failed_attempts": int(store.get("auth_max_failed_attempts") or 5),
        "lockout_minutes": int(store.get("auth_lockout_minutes") or 15),
    }


def validate_password_policy(password: str) -> None:
    policy = get_password_policy()
    min_len = policy["min_length"]
    if len(password) < min_len:
        raise PasswordPolicyError(f"Password must be at least {min_len} characters long")
    if policy["require_uppercase"] and not any(c.isupper() for c in password):
        raise PasswordPolicyError("Password must include at least one uppercase letter (A-Z)")
    if policy["require_lowercase"] and not any(c.islower() for c in password):
        raise PasswordPolicyError("Password must include at least one lowercase letter (a-z)")
    if policy["require_numbers"] and not any(c.isdigit() for c in password):
        raise PasswordPolicyError("Password must include at least one number (0-9)")
    if policy["require_special"] and not re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=/\\[\]~`]", password):
        raise PasswordPolicyError("Password must include at least one special character")


def calculate_password_strength(password: str) -> dict[str, Any]:
    """Calculates password score (0-100) and strength level."""
    score = 0
    if len(password) >= 8:
        score += 25
    if len(password) >= 12:
        score += 15
    if any(c.isupper() for c in password):
        score += 20
    if any(c.islower() for c in password):
        score += 10
    if any(c.isdigit() for c in password):
        score += 15
    if re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=/\\[\]~`]", password):
        score += 15

    if score < 40:
        level = "WEAK"
    elif score < 70:
        level = "MEDIUM"
    elif score < 90:
        level = "STRONG"
    else:
        level = "VERY_STRONG"

    return {"score": min(score, 100), "level": level}


# ---------------------------------------------------------------- Argon2id Hashing
def hash_password(password: str) -> str:
    salt = os.urandom(16)
    kdf = Argon2id(salt=salt, length=32, iterations=2, lanes=4, memory_cost=65536)
    derived = kdf.derive(password.encode("utf-8"))
    salt_b64 = base64.b64encode(salt).decode("utf-8")
    hash_b64 = base64.b64encode(derived).decode("utf-8")
    return f"$argon2id$v=19$m=65536,t=2,p=4${salt_b64}${hash_b64}"


def verify_password(password: str, hashed: str) -> bool:
    try:
        parts = hashed.split("$")
        if len(parts) != 6 or parts[1] != "argon2id":
            return False
        params = dict(p.split("=") for p in parts[3].split(","))
        salt = base64.b64decode(parts[4])
        expected = base64.b64decode(parts[5])
        kdf = Argon2id(
            salt=salt,
            length=len(expected),
            iterations=int(params.get("t", 2)),
            lanes=int(params.get("p", 4)),
            memory_cost=int(params.get("m", 65536)),
        )
        kdf.verify(password.encode("utf-8"), expected)
        return True
    except (InvalidKey, Exception):
        return False


# ---------------------------------------------------------------- JWT Tokens (RFC 7519)
def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def _b64url_decode(s: str) -> bytes:
    padding = "=" * ((4 - len(s) % 4) % 4)
    return base64.urlsafe_b64decode((s + padding).encode("utf-8"))


def create_jwt(payload: dict[str, Any], expires_delta: timedelta) -> str:
    secret = get_settings().secret_key.encode("utf-8")
    header = {"alg": "HS256", "typ": "JWT"}
    exp = int((utcnow() + expires_delta).timestamp())
    full_payload = {**payload, "exp": exp, "iat": int(utcnow().timestamp())}

    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(full_payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")

    signature = hmac.new(secret, signing_input, hashlib.sha256).digest()
    sig_b64 = _b64url_encode(signature)
    return f"{header_b64}.{payload_b64}.{sig_b64}"


def decode_jwt(token: str) -> dict[str, Any]:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("Invalid JWT format")
        header_b64, payload_b64, sig_b64 = parts
        signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
        secret = get_settings().secret_key.encode("utf-8")

        expected_sig = hmac.new(secret, signing_input, hashlib.sha256).digest()
        actual_sig = _b64url_decode(sig_b64)
        if not hmac.compare_digest(expected_sig, actual_sig):
            raise ValueError("Invalid signature")

        payload = json.loads(_b64url_decode(payload_b64).decode("utf-8"))
        exp = payload.get("exp")
        if exp and exp < int(utcnow().timestamp()):
            raise ValueError("Token has expired")
        return payload
    except Exception as exc:
        raise ValueError(f"Invalid token: {exc}") from exc


# ---------------------------------------------------------------- Session / Token Management
def create_tokens(db: Session, user: User, remember_me: bool = False, user_agent: str | None = None, ip_address: str | None = None) -> dict[str, Any]:
    access_expiry_min = int(store.get("auth_token_expire_minutes") or 60)
    access_token = create_jwt(
        {"sub": str(user.id), "username": user.username, "email": user.email, "role": user.role},
        timedelta(minutes=access_expiry_min),
    )

    refresh_days = 30 if remember_me else int(store.get("auth_refresh_expire_days") or 7)
    raw_refresh = secrets.token_urlsafe(48)
    refresh_hash = hashlib.sha256(raw_refresh.encode("utf-8")).hexdigest()

    session = UserSession(
        user_id=user.id,
        refresh_token_hash=refresh_hash,
        expires_at=utcnow() + timedelta(days=refresh_days),
        user_agent=(user_agent or "")[:250],
        ip_address=(ip_address or "")[:60],
    )
    db.add(session)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": raw_refresh,
        "token_type": "Bearer",
        "expires_in": access_expiry_min * 60,
    }


def refresh_access_token(db: Session, raw_refresh_token: str) -> dict[str, Any]:
    refresh_hash = hashlib.sha256(raw_refresh_token.encode("utf-8")).hexdigest()
    stmt = select(UserSession).where(
        UserSession.refresh_token_hash == refresh_hash,
        UserSession.revoked.is_(False),
        UserSession.expires_at > utcnow(),
    )
    session = db.scalar(stmt)
    if not session:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired refresh token")

    user = db.get(User, session.user_id)
    if not user or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Account is disabled")

    access_expiry_min = int(store.get("auth_token_expire_minutes") or 60)
    new_access_token = create_jwt(
        {"sub": str(user.id), "username": user.username, "email": user.email, "role": user.role},
        timedelta(minutes=access_expiry_min),
    )
    return {
        "access_token": new_access_token,
        "token_type": "Bearer",
        "expires_in": access_expiry_min * 60,
    }


def revoke_session(db: Session, raw_refresh_token: str) -> bool:
    refresh_hash = hashlib.sha256(raw_refresh_token.encode("utf-8")).hexdigest()
    stmt = select(UserSession).where(UserSession.refresh_token_hash == refresh_hash)
    session = db.scalar(stmt)
    if session:
        session.revoked = True
        db.commit()
        return True
    return False


# ---------------------------------------------------------------- Account Security & Lockout
def record_login_attempt(db: Session, user: User, success: bool) -> None:
    policy = get_password_policy()
    max_attempts = policy["max_failed_attempts"]
    lockout_minutes = policy["lockout_minutes"]

    if success:
        user.failed_login_attempts = 0
        user.locked_until = None
        user.last_login_at = utcnow()
    else:
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= max_attempts:
            user.locked_until = utcnow() + timedelta(minutes=lockout_minutes)
            log.warning(f"Account {user.username} locked due to {user.failed_login_attempts} failed login attempts")
    db.commit()


def check_account_locked(user: User) -> None:
    if user.locked_until and user.locked_until > utcnow():
        remaining = int((user.locked_until - utcnow()).total_seconds() / 60) + 1
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            f"Account is temporarily locked due to excessive failed attempts. Try again in {remaining} minute(s).",
        )
