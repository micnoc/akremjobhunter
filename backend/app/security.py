"""API authentication, JWT Bearer validation, rate limiting and at-rest encryption of stored secrets."""
from __future__ import annotations

import base64
import hashlib
import secrets
import time
from collections import defaultdict
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken
from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from .config import get_settings
from .db import get_db

_fernet = Fernet(base64.urlsafe_b64encode(hashlib.sha256(get_settings().secret_key.encode()).digest()))

# IP rate-limiting for failed attempts
_failures: dict[str, list[float]] = defaultdict(list)
_WINDOW = 900  # 15 minutes
_MAX_FAILURES = 10


def encrypt(value: str) -> str:
    return _fernet.encrypt(value.encode()).decode()


def decrypt(token: str) -> str:
    try:
        return _fernet.decrypt(token.encode()).decode()
    except InvalidToken:
        return ""


def _check_ip_failures(ip: str) -> None:
    now = time.time()
    _failures[ip] = [t for t in _failures[ip] if now - t < _WINDOW]
    if len(_failures[ip]) >= _MAX_FAILURES:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many failed attempts. Try again later.")


def _record_ip_failure(ip: str) -> None:
    _failures[ip].append(time.time())


def require_access(request: Request, authorization: str = Header(default="")) -> dict:
    """Validates authorization header via either JWT Bearer token or master access key."""
    from .auth import decode_jwt

    ip = request.client.host if request.client else "unknown"
    _check_ip_failures(ip)

    raw_token = authorization.removeprefix("Bearer ").strip()
    if not raw_token:
        _record_ip_failure(ip)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing authorization header")

    # 1. Master access key check (backwards compatibility / initial setup)
    if secrets.compare_digest(raw_token, get_settings().access_key):
        return {"sub": "master", "role": "admin", "type": "access_key"}

    # 2. JWT Bearer token check
    try:
        payload = decode_jwt(raw_token)
        return payload
    except Exception:
        _record_ip_failure(ip)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired access token")


def get_current_user(
    token_data: dict = Depends(require_access),
    db: Session = Depends(get_db),
):
    from .models import User

    if token_data.get("type") == "access_key":
        # Master access key used: find first admin or return None
        return db.query(User).filter(User.role == "admin").first()

    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token payload")

    user = db.get(User, int(user_id))
    if not user or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User account is inactive or not found")
    return user
