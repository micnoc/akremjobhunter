"""REST API consumed by the mobile app. Every route except /health requires the access key."""
from __future__ import annotations

import json
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from . import ai, cvs as cv_service, mailer, notifier, pipeline
from . import settings_store as store
from .config import get_settings
from .db import get_db
from .models import Application, AppStatus, Cv, EmailEvent, EngineRun, Job, JobStatus, utcnow
from .probability_engine import OfferProbabilityEngine
from .security import require_access
from .sources import adzuna

router = APIRouter(prefix="/api/v1", dependencies=[Depends(require_access)])

BUCKETS = {
    "review": [AppStatus.AWAITING_USER],
    "queue": [AppStatus.QUEUED, AppStatus.FAILED],
    "sent": [AppStatus.SENT, AppStatus.APPLIED_MANUAL, AppStatus.ACKNOWLEDGED],
    "responses": [AppStatus.IN_PROGRESS, AppStatus.INTERVIEW, AppStatus.OFFER, AppStatus.REJECTED],
    "skipped": [AppStatus.SKIPPED],
}
POSITIVE = [AppStatus.IN_PROGRESS, AppStatus.INTERVIEW, AppStatus.OFFER]


def _iso(dt):
    return dt.isoformat() if dt else None


def _app_summary(a: Application) -> dict:
    j = a.job
    missing_cnt = 0
    try:
        missing_cnt = len(json.loads(j.missing_skills or "[]"))
    except Exception:
        pass
    prob = OfferProbabilityEngine.calculate(
        match_score=j.match_score,
        eligibility=j.eligibility,
        country=j.country,
        job_language=j.language,
        cv_language=a.cv.language if a.cv else "en",
        has_direct_email=bool(j.apply_email or j.recruiter_email),
        missing_skills_count=missing_cnt,
    )
    return {
        "id": a.id, "status": a.status, "method": a.method, "title": j.title, "company": j.company,
        "country": j.country, "location": j.location, "score": j.match_score, "eligibility": j.eligibility,
        "cv_label": a.cv.label if a.cv else None, "created_at": _iso(a.created_at), "sent_at": _iso(a.sent_at),
        "url": j.url, "source": j.source, "last_response_at": _iso(a.last_response_at),
        "response_summary": a.response_summary,
        "probability": prob,
    }


# ---------------------------------------------------------------- dashboard
@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db)) -> dict:
    week = utcnow() - timedelta(days=7)

    def count(stmt) -> int:
        return db.scalar(stmt) or 0

    last_runs = {}
    for kind in ("discover", "evaluate", "send", "inbox"):
        run = db.scalar(select(EngineRun).where(EngineRun.kind == kind).order_by(EngineRun.id.desc()).limit(1))
        if run:
            last_runs[kind] = {"at": _iso(run.started_at), "ok": run.ok, "detail": run.detail}
    status_counts = dict(db.execute(select(Application.status, func.count()).group_by(Application.status)).all())
    recent = db.scalars(select(Application).order_by(Application.id.desc()).limit(8))
    return {
        "engine": {"paused": bool(store.get("engine_paused")), "last_runs": last_runs},
        "config": {
            "gmail": bool(store.get("gmail_address") and store.get("gmail_app_password")),
            "ai": bool(store.get("ai_api_key")),
            "telegram": bool(store.get("telegram_bot_token") and store.get("telegram_chat_id")),
            "cvs": count(select(func.count(Cv.id)).where(Cv.active.is_(True))),
            "adzuna": bool(store.get("adzuna_app_id") and store.get("adzuna_app_key")),
        },
        "quota": {"used": pipeline.sent_today(db), "limit": pipeline.daily_limit()},
        "counts": {
            "jobs_7d": count(select(func.count(Job.id)).where(Job.discovered_at >= week)),
            "eligible_7d": count(select(func.count(Job.id)).where(Job.discovered_at >= week, Job.status == JobStatus.MATCHED)),
            "pending_screening": count(select(func.count(Job.id)).where(Job.status == JobStatus.NEW)),
            "review": status_counts.get(AppStatus.AWAITING_USER, 0),
            "queued": status_counts.get(AppStatus.QUEUED, 0),
            "submitted": sum(status_counts.get(s, 0) for s in BUCKETS["sent"] + BUCKETS["responses"]),
            "interviews": status_counts.get(AppStatus.INTERVIEW, 0),
            "offers": status_counts.get(AppStatus.OFFER, 0),
            "positive": sum(status_counts.get(s, 0) for s in POSITIVE),
            "rejected": status_counts.get(AppStatus.REJECTED, 0),
        },
        "recent": [_app_summary(a) for a in recent],
    }


# ---------------------------------------------------------------- applications
@router.get("/applications")
def list_applications(bucket: str = "all", limit: int = 50, offset: int = 0, db: Session = Depends(get_db)) -> dict:
    stmt = select(Application).order_by(Application.id.desc())
    if bucket in BUCKETS:
        stmt = stmt.where(Application.status.in_(BUCKETS[bucket]))
    items = db.scalars(stmt.offset(offset).limit(min(limit, 200)))
    return {"items": [_app_summary(a) for a in items]}


@router.get("/applications/{app_id}")
def get_application(app_id: int, db: Session = Depends(get_db)) -> dict:
    a = db.get(Application, app_id)
    if not a:
        raise HTTPException(404, "Not found")
    j = a.job
    events = db.scalars(select(EmailEvent).where(EmailEvent.application_id == a.id).order_by(EmailEvent.id.desc()))
    return {
        **_app_summary(a),
        "to_email": a.to_email, "cc_email": a.cc_email, "cover_subject": a.cover_subject,
        "cover_letter": a.cover_letter, "error": a.error, "follow_up_sent_at": _iso(a.follow_up_sent_at),
        "job": {
            "description": j.description, "eligibility_evidence": j.eligibility_evidence, "summary": j.summary,
            "missing_skills": json.loads(j.missing_skills or "[]"), "language": j.language,
            "international_hint": j.international_hint, "posted_at": _iso(j.posted_at),
        },
        "events": [
            {
                "id": e.id, "from": e.from_addr, "subject": e.subject, "category": e.category, "evidence": e.evidence,
                "summary": e.summary, "draft_reply": e.draft_reply, "reply_sent": e.reply_sent,
                "received_at": _iso(e.received_at), "has_prep": bool(e.prep_pdf),
            }
            for e in events
        ],
    }


class ActionIn(BaseModel):
    action: str


@router.post("/applications/{app_id}/action")
def application_action(app_id: int, body: ActionIn) -> dict:
    if body.action not in {"send", "applied", "skip", "requeue"}:
        raise HTTPException(400, "Unknown action")
    return {"result": pipeline.application_action(app_id, body.action)}


class LetterIn(BaseModel):
    subject: str
    body: str


@router.put("/applications/{app_id}/letter")
def update_letter(app_id: int, body: LetterIn, db: Session = Depends(get_db)) -> dict:
    a = db.get(Application, app_id)
    if not a:
        raise HTTPException(404, "Not found")
    if a.status in (AppStatus.SENT, AppStatus.APPLIED_MANUAL):
        raise HTTPException(409, "Already submitted")
    a.cover_subject, a.cover_letter = body.subject.strip(), body.body.strip()
    return {"result": "saved"}


class ReplyIn(BaseModel):
    action: str
    body: str | None = None


@router.post("/events/{event_id}/reply")
def event_reply(event_id: int, body: ReplyIn) -> dict:
    return {"result": pipeline.reply_action(event_id, body.action, body.body)}


@router.get("/events/{event_id}/prep")
def event_prep(event_id: int, db: Session = Depends(get_db)):
    e = db.get(EmailEvent, event_id)
    if not e or not e.prep_pdf:
        raise HTTPException(404, "No preparation pack")
    return FileResponse(f"{get_settings().reports_dir}/{e.prep_pdf}", media_type="application/pdf", filename=e.prep_pdf)


# ---------------------------------------------------------------- jobs feed
@router.get("/jobs")
def list_jobs(status: str | None = None, limit: int = 60, db: Session = Depends(get_db)) -> dict:
    stmt = select(Job).order_by(Job.discovered_at.desc())
    if status:
        stmt = stmt.where(Job.status == status)
    items = [
        {
            "id": j.id, "title": j.title, "company": j.company, "country": j.country, "location": j.location,
            "source": j.source, "status": j.status, "eligibility": j.eligibility, "score": j.match_score,
            "evidence": j.eligibility_evidence, "url": j.url, "discovered_at": _iso(j.discovered_at),
        }
        for j in db.scalars(stmt.limit(min(limit, 200)))
    ]
    counts = dict(db.execute(select(Job.status, func.count()).group_by(Job.status)).all())
    return {"items": items, "counts": counts}


# ---------------------------------------------------------------- CV vault
@router.get("/cvs")
def list_cvs(db: Session = Depends(get_db)) -> dict:
    return {"items": [cv_service.to_dict(c) for c in db.scalars(select(Cv).order_by(Cv.id.desc()))]}


@router.post("/cvs")
async def upload_cvs(files: list[UploadFile] = File(...), db: Session = Depends(get_db)) -> dict:
    created, errors = [], []
    for f in files[:10]:
        content = await f.read()
        try:
            cv = cv_service.store_cv(db, f.filename or "cv.pdf", content)
            created.append(cv_service.to_dict(cv))
        except cv_service.CvError as exc:
            errors.append(str(exc))
    return {"created": created, "errors": errors}


class CvPatch(BaseModel):
    label: str | None = None
    language: str | None = None
    sector: str | None = None
    target_titles: list[str] | None = None
    active: bool | None = None


@router.patch("/cvs/{cv_id}")
def patch_cv(cv_id: int, body: CvPatch, db: Session = Depends(get_db)) -> dict:
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "Not found")
    data = body.model_dump(exclude_none=True)
    if "target_titles" in data:
        data["target_titles"] = json.dumps([t.strip() for t in data["target_titles"] if t.strip()][:8], ensure_ascii=False)
    for k, v in data.items():
        setattr(cv, k, v)
    return cv_service.to_dict(cv)


@router.delete("/cvs/{cv_id}")
def delete_cv(cv_id: int, db: Session = Depends(get_db)) -> dict:
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "Not found")
    cv_service.delete_cv(db, cv)
    return {"result": "deleted"}


@router.get("/cvs/{cv_id}/file")
def cv_file(cv_id: int, db: Session = Depends(get_db)):
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "Not found")
    return FileResponse(cv_service.cv_path(cv), media_type="application/pdf", filename=cv.original_name)


# ---------------------------------------------------------------- insights
@router.get("/insights")
def insights(db: Session = Depends(get_db)) -> dict:
    submitted = BUCKETS["sent"] + BUCKETS["responses"]
    job_rows = db.execute(
        select(
            Job.country, func.count(Job.id),
            func.sum(case((Job.status == JobStatus.MATCHED, 1), else_=0)),
        ).group_by(Job.country)
    ).all()
    app_rows = db.execute(
        select(
            Job.country,
            func.sum(case((Application.status.in_(submitted), 1), else_=0)),
            func.sum(case((Application.last_response_at.is_not(None), 1), else_=0)),
            func.sum(case((Application.status.in_(POSITIVE), 1), else_=0)),
        ).join(Job, Application.job_id == Job.id).group_by(Job.country)
    ).all()
    apps = {r[0]: r[1:] for r in app_rows}
    countries = []
    for country, found, eligible in job_rows:
        applied, responses, positive = apps.get(country, (0, 0, 0))
        applied, responses, positive = int(applied or 0), int(responses or 0), int(positive or 0)
        countries.append({
            "country": country, "found": int(found or 0), "eligible": int(eligible or 0), "applied": applied,
            "responses": responses, "positive": positive,
            "conversion": round(positive / applied * 100, 1) if applied else 0.0,
        })
    countries.sort(key=lambda c: c["found"], reverse=True)
    elig = dict(db.execute(select(Job.eligibility, func.count()).where(Job.eligibility.is_not(None)).group_by(Job.eligibility)).all())
    sources = [
        {"source": s, "found": int(n), "matched": int(m or 0)}
        for s, n, m in db.execute(
            select(Job.source, func.count(Job.id), func.sum(case((Job.status == JobStatus.MATCHED, 1), else_=0)))
            .group_by(Job.source)
        ).all()
    ]
    return {"countries": countries, "eligibility": elig, "sources": sources, "skill_gaps": pipeline.skill_gaps(db)}


# ---------------------------------------------------------------- settings
@router.get("/settings")
def get_settings_view() -> dict:
    return store.public_view()


@router.put("/settings")
def put_settings(values: dict[str, Any]) -> dict:
    clean = {}
    for k, v in values.items():
        if k not in store.DEFAULTS or k in store.INTERNAL_KEYS:
            continue
        if k in store.SECRET_KEYS and (v is None or (isinstance(v, str) and not v.strip())):
            continue  # empty secret field means "keep current"
        if isinstance(v, str):
            v = v.strip()
        clean[k] = v
    if "gmail_address" in clean or "telegram_bot_token" in clean:
        if "telegram_bot_token" in clean:
            clean["telegram_chat_id"] = ""  # relink chat for a new bot
        if "gmail_address" in clean:
            store.put("imap_last_uid", 0)
    store.set_many(clean)
    return store.public_view()


@router.post("/settings/test/{target}")
def test_integration(target: str) -> dict:
    try:
        if target == "gmail":
            mailer.test_connection()
            return {"ok": True, "message": "IMAP and SMTP authentication succeeded"}
        if target == "ai":
            info = ai.ping()
            return {"ok": True, "message": f"{info.get('model', 'AI Engine')} is ONLINE (Ready to evaluate & write)", "details": info}
        if target == "telegram":
            return {"ok": True, "message": notifier.test_telegram()}
        if target == "whatsapp":
            ok = notifier.send_whatsapp("akremjobhunter: WhatsApp channel verified.")
            return {"ok": ok, "message": "Delivered" if ok else "Delivery failed (check phone / API key)"}
        if target == "adzuna":
            return {"ok": True, "message": adzuna.test()}
    except Exception as exc:
        return {"ok": False, "message": str(exc)[:300]}
    raise HTTPException(404, "Unknown integration")


@router.get("/ai/models")
def ai_models() -> dict:
    try:
        return {"items": ai.list_models(), "auto": ai.resolve_model() if not store.get("ai_model") else None}
    except Exception as exc:
        raise HTTPException(400, str(exc)) from exc


# ---------------------------------------------------------------- engine control
ENGINE_TASKS = {
    "discover": pipeline.discover,
    "evaluate": pipeline.evaluate_pending,
    "inbox": pipeline.check_inbox,
    "send": pipeline.send_due,
}


@router.post("/engine/{action}")
def engine(action: str, background: BackgroundTasks) -> dict:
    if action == "pause":
        store.put("engine_paused", True)
        return {"result": "Engine paused"}
    if action == "resume":
        store.put("engine_paused", False)
        return {"result": "Engine running"}
    fn = ENGINE_TASKS.get(action)
    if not fn:
        raise HTTPException(404, "Unknown action")
    background.add_task(fn)
    return {"result": f"{action} started"}


@router.get("/runs")
def runs(limit: int = 40, db: Session = Depends(get_db)) -> dict:
    items = db.scalars(select(EngineRun).order_by(EngineRun.id.desc()).limit(min(limit, 200)))
    return {"items": [
        {"kind": r.kind, "started_at": _iso(r.started_at), "finished_at": _iso(r.finished_at), "ok": r.ok, "detail": r.detail}
        for r in items
    ]}
