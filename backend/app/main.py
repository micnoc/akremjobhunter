"""Main FastAPI application entry point with lifespan management."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .admin_routes import router as admin_router
from .api import router as api_router
from .auth_routes import router as auth_router
from .config import get_settings
from .db import init_db
from .notifier import TelegramPoller
from .pipeline import handle_callback
from .scheduler import build_scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Starting akremjobhunter cloud engine...")
    init_db()

    sched = build_scheduler()
    sched.start()
    log.info("Background scheduler running 24/7.")

    poller = TelegramPoller(on_callback=handle_callback)
    poller.start()
    log.info("Telegram interactive poller active.")

    yield

    log.info("Shutting down cloud engine...")
    poller.stop()
    sched.shutdown(wait=False)
    log.info("Shutdown complete.")


app = FastAPI(
    title="VisaJob AI Cloud Engine",
    version="3.1.0",
    description="VisaJob AI — Your Global AI Employment & Immigration Agent by Akrem Hidouri",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(api_router)
app.include_router(admin_router)


@app.get("/health")
def health():
    return {
        "status": "ONLINE",
        "app_name": "VisaJob AI",
        "author": "Akrem Hidouri",
        "engine": "visajob_ai_multi_agent",
        "version": "3.1.0",
        "timezone": get_settings().timezone,
    }
