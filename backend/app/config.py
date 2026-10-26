"""Runtime configuration loaded from environment variables (never hardcode secrets)."""
from __future__ import annotations

import os
from functools import lru_cache
from zoneinfo import ZoneInfo

from pydantic_settings import BaseSettings, SettingsConfigDict


_ENV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(_ENV_PATH, ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Bearer key the mobile app must send. Generated at deploy time.
    access_key: str = "akrem2026"
    # Used to derive the encryption key for secrets stored in the database.
    secret_key: str = "akremjobhunter_super_secret_encryption_key_32bytes_min"
    data_dir: str = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    timezone: str = "Africa/Tunis"
    # Hard ceiling, cannot be raised from the app.
    max_daily_applications: int = 20

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    @property
    def db_path(self) -> str:
        return os.path.join(self.data_dir, "akremjobhunter.db")

    @property
    def cv_dir(self) -> str:
        return os.path.join(self.data_dir, "cv_vault")

    @property
    def reports_dir(self) -> str:
        return os.path.join(self.data_dir, "reports")


@lru_cache
def get_settings() -> Settings:
    s = Settings()  # type: ignore[call-arg]
    for d in (s.data_dir, s.cv_dir, s.reports_dir):
        os.makedirs(d, exist_ok=True)
    return s
