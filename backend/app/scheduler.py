"""Background scheduler (runs inside the server process, independent of the phone)."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from . import pipeline
from .config import get_settings

log = logging.getLogger("scheduler")


def build_scheduler() -> BackgroundScheduler:
    tz = get_settings().tz
    sched = BackgroundScheduler(timezone=tz, job_defaults={"coalesce": True, "max_instances": 1, "misfire_grace_time": 600})
    first = datetime.now(tz) + timedelta(minutes=2)
    sched.add_job(pipeline.discover, IntervalTrigger(hours=3, jitter=900), id="discover", next_run_time=first)
    sched.add_job(pipeline.evaluate_pending, IntervalTrigger(minutes=30, jitter=120), id="evaluate")
    sched.add_job(pipeline.send_due, IntervalTrigger(minutes=10, jitter=240), id="send")
    sched.add_job(pipeline.check_inbox, IntervalTrigger(minutes=15, jitter=90), id="inbox")
    sched.add_job(pipeline.follow_ups, CronTrigger(hour=10, minute=17), id="follow_ups")
    sched.add_job(pipeline.weekly_report, CronTrigger(day_of_week="mon", hour=9, minute=5), id="weekly")
    return sched
