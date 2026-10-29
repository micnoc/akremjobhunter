"""User-configurable settings persisted in the database. Secrets are encrypted at rest."""
from __future__ import annotations

import json
from typing import Any

from .config import get_settings
from .db import session_scope
from .models import SettingRow, UserSetting
from .security import decrypt, encrypt

SECRET_KEYS = {
    "gmail_app_password",
    "ai_api_key",
    "adzuna_app_key",
    "telegram_bot_token",
    "callmebot_apikey",
}

ALL_COUNTRIES = [
    "DE", "FR", "BE", "NL", "LU", "CH", "AT", "IT", "ES", "PT", "IE",
    "PL", "CZ", "SE", "DK", "NO", "FI", "GB", "CA", "US",
]

DEFAULTS: dict[str, Any] = {
    "full_name": "",
    "phone": "",
    "gmail_address": "",
    "gmail_app_password": "",
    "ai_api_key": "",
    "ai_model": "",  # empty -> auto-select the strongest available "pro" model
    "adzuna_app_id": "",
    "adzuna_app_key": "",
    "telegram_bot_token": "",
    "telegram_chat_id": "",
    "whatsapp_phone": "",
    "callmebot_apikey": "",
    "target_countries": ["DE", "FR", "BE", "NL", "LU", "CH", "AT", "CA", "US"],
    "search_keywords": [],  # empty -> use target titles extracted from active CVs
    "sources_enabled": ["jobbank", "eures", "careerjet", "jooble", "company_careers", "arbeitnow"],
    "daily_limit": 20,
    "min_match_score": 70,
    "allow_unclear_eligibility": False,
    "auto_send": True,
    "notify_manual_review": True,
    "follow_up_days": 8,
    "engine_paused": False,
    "notification_language": "ar",  # ar | fr | en
    # Authentication Policy (Configurable by admin)
    "auth_min_password_length": 8,
    "auth_require_uppercase": True,
    "auth_require_lowercase": True,
    "auth_require_numbers": True,
    "auth_require_special": False,
    "auth_max_failed_attempts": 5,
    "auth_lockout_minutes": 15,
    "auth_token_expire_minutes": 60,
    "auth_refresh_expire_days": 30,
    # internal state
    "imap_last_uid": 0,
    "telegram_update_offset": 0,
}

INTERNAL_KEYS = {"imap_last_uid", "telegram_update_offset"}


def get(key: str, user_id: int | None = None) -> Any:
    with session_scope() as s:
        if user_id is not None:
            user_row = s.get(UserSetting, (user_id, key))
            if user_row is not None:
                raw = decrypt(user_row.value) if key in SECRET_KEYS else user_row.value
                try:
                    return json.loads(raw)
                except (json.JSONDecodeError, TypeError):
                    return raw

        row = s.get(SettingRow, key)
        if row is None:
            return DEFAULTS.get(key)
        raw = decrypt(row.value) if key in SECRET_KEYS else row.value
        try:
            return json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            return raw


def set_many(values: dict[str, Any], user_id: int | None = None) -> None:
    with session_scope() as s:
        for key, val in values.items():
            if key not in DEFAULTS:
                continue
            if key == "daily_limit":
                val = max(1, min(int(val), get_settings().max_daily_applications))
            if key == "min_match_score":
                val = max(0, min(int(val), 100))
            raw = json.dumps(val)
            if key in SECRET_KEYS:
                raw = encrypt(raw)

            if user_id is not None:
                user_row = s.get(UserSetting, (user_id, key))
                if user_row is None:
                    s.add(UserSetting(user_id=user_id, key=key, value=raw))
                else:
                    user_row.value = raw
            else:
                row = s.get(SettingRow, key)
                if row is None:
                    s.add(SettingRow(key=key, value=raw))
                else:
                    row.value = raw


def put(key: str, value: Any, user_id: int | None = None) -> None:
    set_many({key: value}, user_id=user_id)


def public_view(user_id: int | None = None) -> dict[str, Any]:
    """Settings for the mobile app: secrets are never returned, only whether they are set."""
    out: dict[str, Any] = {}
    for key in DEFAULTS:
        if key in INTERNAL_KEYS:
            continue
        val = get(key, user_id=user_id)
        if key in SECRET_KEYS:
            out[key] = {"is_set": bool(val)}
        else:
            out[key] = val
    out["max_daily_applications"] = get_settings().max_daily_applications
    out["all_countries"] = ALL_COUNTRIES
    return out
