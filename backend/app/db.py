"""Database engine and session management. Supports PostgreSQL (Cloud) and SQLite (Local fallback)."""
from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings


class Base(DeclarativeBase):
    pass


_settings = get_settings()
raw_db_url = os.environ.get("DATABASE_URL", "").strip()

# Handle Render / Railway postgres:// alias to postgresql://
if raw_db_url.startswith("postgres://"):
    raw_db_url = raw_db_url.replace("postgres://", "postgresql://", 1)

if raw_db_url:
    # Cloud PostgreSQL Engine
    engine = create_engine(
        raw_db_url,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
    )
else:
    # Local SQLite Engine
    engine = create_engine(
        f"sqlite:///{_settings.db_path}",
        connect_args={"check_same_thread": False, "timeout": 30},
        pool_pre_ping=True,
    )

    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_conn, _record):  # pragma: no cover
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA journal_mode=WAL")
        cur.execute("PRAGMA synchronous=NORMAL")
        cur.execute("PRAGMA foreign_keys=ON")
        cur.close()


SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


@contextmanager
def session_scope() -> Iterator[Session]:
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_db() -> Iterator[Session]:
    """FastAPI dependency."""
    with session_scope() as s:
        yield s


def init_db() -> None:
    from . import models  # noqa: F401  (register tables)

    Base.metadata.create_all(engine)

    # Safe lightweight schema migration for new columns
    try:
        with engine.begin() as conn:
            insp = inspect(conn)
            tables = insp.get_table_names()
            if "users" in tables:
                user_cols = {c["name"] for c in insp.get_columns("users")}
                if "full_name" not in user_cols:
                    conn.execute(text("ALTER TABLE users ADD COLUMN full_name VARCHAR(200)"))
                if "country_code" not in user_cols:
                    conn.execute(text("ALTER TABLE users ADD COLUMN country_code VARCHAR(10)"))
                if "phone" not in user_cols:
                    conn.execute(text("ALTER TABLE users ADD COLUMN phone VARCHAR(50)"))
            if "cvs" in tables:
                cvs_cols = {c["name"] for c in insp.get_columns("cvs")}
                if "user_id" not in cvs_cols:
                    conn.execute(text("ALTER TABLE cvs ADD COLUMN user_id INTEGER"))
            if "applications" in tables:
                app_cols = {c["name"] for c in insp.get_columns("applications")}
                if "user_id" not in app_cols:
                    conn.execute(text("ALTER TABLE applications ADD COLUMN user_id INTEGER"))
    except Exception as exc:
        import logging
        logging.getLogger("db").warning(f"Lightweight schema check note: {exc}")
