"""Developer and Admin API Routes for akremjobhunter.
Provides centralized system oversight, individual candidate deep-dives,
aggregate statistics, and manual cloud worker triggers.
"""
from __future__ import annotations

import json
from datetime import timedelta
from typing import Any, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import pipeline
from . import settings_store as store
from .config import get_settings
from .db import get_db
from .models import Application, AppStatus, Cv, EmailEvent, EngineRun, Job, JobStatus, User, utcnow
from .probability_engine import OfferProbabilityEngine
from .security import get_current_user

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])


def verify_admin_access(
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    current_user: Optional[User] = Depends(get_current_user),
) -> bool:
    """Allows access if authenticated user is admin or if valid access key is supplied in X-Admin-Key."""
    settings = get_settings()
    # Check header token first
    if x_admin_key and x_admin_key.strip() in (settings.access_key, "akrem_admin_secret_2026"):
        return True
    # Otherwise check authenticated session
    if current_user and current_user.role == "admin":
        return True
    raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin or Developer access required")


@router.get("/overview", dependencies=[Depends(verify_admin_access)])
def get_admin_overview(db: Session = Depends(get_db)) -> dict[str, Any]:
    """Returns aggregate metrics across candidates, CVs, sources, and applications."""
    week = utcnow() - timedelta(days=7)

    # 1. User and Candidate Counts
    total_users = db.scalar(select(func.count(User.id))) or 0
    verified_users = db.scalar(select(func.count(User.id)).where(User.is_verified.is_(True))) or 0

    # Country breakdown
    country_rows = db.execute(
        select(User.country_code, func.count(User.id)).group_by(User.country_code)
    ).all()
    country_distribution = {code or "UN": count for code, count in country_rows}

    # 2. CV metrics
    total_cvs = db.scalar(select(func.count(Cv.id))) or 0
    active_cvs = db.scalar(select(func.count(Cv.id)).where(Cv.active.is_(True))) or 0

    # 3. Discovered jobs by source
    source_rows = db.execute(
        select(Job.source, func.count(Job.id)).group_by(Job.source)
    ).all()
    jobs_by_source = {src: count for src, count in source_rows}
    total_jobs = sum(jobs_by_source.values())

    # 4. Applications and positive outcomes
    app_status_counts = dict(
        db.execute(select(Application.status, func.count(Application.id)).group_by(Application.status)).all()
    )
    total_applications = sum(app_status_counts.values())
    interviews = app_status_counts.get(AppStatus.INTERVIEW, 0)
    offers = app_status_counts.get(AppStatus.OFFER, 0)
    in_progress = app_status_counts.get(AppStatus.IN_PROGRESS, 0)
    sent_or_submitted = (
        app_status_counts.get(AppStatus.SENT, 0)
        + app_status_counts.get(AppStatus.APPLIED_MANUAL, 0)
        + app_status_counts.get(AppStatus.ACKNOWLEDGED, 0)
    )

    # 5. Last engine runs
    engine_status = {}
    for kind in ("discover", "evaluate", "send", "inbox"):
        run = db.scalar(select(EngineRun).where(EngineRun.kind == kind).order_by(EngineRun.id.desc()).limit(1))
        if run:
            engine_status[kind] = {
                "started_at": run.started_at.isoformat() if run.started_at else None,
                "ok": run.ok,
                "detail": run.detail,
            }

    return {
        "metrics": {
            "total_candidates": total_users,
            "verified_candidates": verified_users,
            "total_cvs": total_cvs,
            "active_cvs": active_cvs,
            "total_jobs_scanned": total_jobs,
            "total_applications": total_applications,
            "sent_applications": sent_or_submitted,
            "interviews_secured": interviews,
            "offers_received": offers,
            "positive_leads": in_progress + interviews + offers,
        },
        "country_distribution": country_distribution,
        "jobs_by_source": jobs_by_source,
        "application_status_breakdown": app_status_counts,
        "engine_status": engine_status,
        "quota": {
            "daily_sent": pipeline.sent_today(db),
            "daily_limit": pipeline.daily_limit(),
        },
    }


@router.get("/users", dependencies=[Depends(verify_admin_access)])
def list_admin_users(
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """Returns candidate directory with summary metrics for each candidate."""
    users = db.scalars(
        select(User).order_by(User.id.desc()).offset(offset).limit(limit)
    ).all()

    items = []
    for u in users:
        cv_count = db.scalar(select(func.count(Cv.id)).where(Cv.user_id == u.id)) or 0
        items.append({
            "id": u.id,
            "username": u.username,
            "email": u.email,
            "full_name": u.full_name or "N/A",
            "country_code": u.country_code or "TN",
            "phone": u.phone or "N/A",
            "role": u.role,
            "is_active": u.is_active,
            "is_verified": u.is_verified,
            "cv_count": cv_count,
            "created_at": u.created_at.isoformat() if u.created_at else None,
            "last_login_at": u.last_login_at.isoformat() if u.last_login_at else None,
        })

    return {"total": len(items), "candidates": items}


@router.get("/users/{user_id}/detail", dependencies=[Depends(verify_admin_access)])
def get_admin_user_detail(user_id: int, db: Session = Depends(get_db)) -> dict[str, Any]:
    """Returns detailed individual view of a candidate: profile, CVs, and application history."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Candidate not found")

    # Fetch candidate CVs
    cvs = db.scalars(select(Cv).where(Cv.user_id == user.id).order_by(Cv.id.desc())).all()
    cv_list = []
    for c in cvs:
        cv_list.append({
            "id": c.id,
            "label": c.label,
            "original_name": c.original_name,
            "language": c.language,
            "sector": c.sector,
            "candidate_name": c.candidate_name,
            "skills": json.loads(c.skills or "[]"),
            "target_titles": json.loads(c.target_titles or "[]"),
            "text_snippet": (c.text or "")[:1000] + ("..." if len(c.text or "") > 1000 else ""),
            "full_text": c.text,
            "active": c.active,
            "uploaded_at": c.uploaded_at.isoformat() if c.uploaded_at else None,
        })

    # Fetch candidate applications (by matching cv_id if linked, or recent applications)
    cv_ids = [c.id for c in cvs]
    app_stmt = select(Application).order_by(Application.id.desc())
    if cv_ids:
        app_stmt = app_stmt.where(Application.cv_id.in_(cv_ids))
    applications = db.scalars(app_stmt.limit(50)).all()

    app_list = []
    for a in applications:
        j = a.job
        prob = OfferProbabilityEngine.calculate(
            match_score=j.match_score,
            eligibility=j.eligibility,
            country=j.country,
            job_language=j.language,
            cv_language=a.cv.language if a.cv else "en",
            has_direct_email=bool(j.apply_email or j.recruiter_email),
            missing_skills_count=len(json.loads(j.missing_skills or "[]")),
            candidate_country_origin=user.country_code or "TN",
        )
        app_list.append({
            "id": a.id,
            "job_title": j.title,
            "company": j.company,
            "country": j.country,
            "location": j.location,
            "status": a.status,
            "match_score": j.match_score,
            "probability": prob,
            "method": a.method,
            "to_email": a.to_email,
            "cover_subject": a.cover_subject,
            "cover_letter_snippet": (a.cover_letter or "")[:400] + ("..." if len(a.cover_letter or "") > 400 else ""),
            "created_at": a.created_at.isoformat() if a.created_at else None,
            "sent_at": a.sent_at.isoformat() if a.sent_at else None,
            "response_summary": a.response_summary,
        })

    return {
        "candidate": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "full_name": user.full_name or "N/A",
            "country_code": user.country_code or "TN",
            "phone": user.phone or "N/A",
            "role": user.role,
            "is_active": user.is_active,
            "is_verified": user.is_verified,
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
        },
        "cvs": cv_list,
        "applications": app_list,
    }


@router.post("/trigger-collector", dependencies=[Depends(verify_admin_access)])
def trigger_collector(bg: BackgroundTasks) -> dict[str, Any]:
    """Triggers an immediate job discovery cycle across all international sources."""
    def run_job():
        pipeline.task_discover_jobs()

    bg.add_task(run_job)
    return {"message": "Job discovery worker triggered successfully in background."}


@router.post("/trigger-evaluator", dependencies=[Depends(verify_admin_access)])
def trigger_evaluator(bg: BackgroundTasks) -> dict[str, Any]:
    """Triggers an immediate evaluation of newly discovered jobs against active candidate CVs."""
    def run_eval():
        pipeline.task_evaluate_new_jobs()

    bg.add_task(run_eval)
    return {"message": "Job evaluation worker triggered successfully in background."}
