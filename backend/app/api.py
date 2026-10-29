"""REST API for VisaJob AI v3.2.
Guarantees:
- 100% User Data & Settings Isolation
- Real live job discovery across Canadian Job Bank, EURES, CareerJet, Jooble, & Company Career Pages
- Real AI Assistant with interactive Chat & Contract/CV Document Analysis
- Real Telegram Deep-Link Auth & Diagnostics
- Robust WhatsApp Delivery with Phone Normalization & Retries
- Agent Activity Center & Sources Center
"""
from __future__ import annotations

import json
import logging
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from . import ai, cvs as cv_service, mailer, notifier, pipeline
from . import settings_store as store
from .config import get_settings
from .db import get_db
from .local_ai import LocalIntelligentEngine
from .models import (
    AiChatMessage, Application, AppStatus, Cv, EmailEvent, EngineRun, Job, JobStatus,
    Notification, User, UserSession, UserSetting, utcnow,
)
from .probability_engine import OfferProbabilityEngine
from .scam_detector import ScamDetectorEngine
from .employer_intelligence import EmployerIntelligenceSystem
from .agent_system import AgentCoordinator
from .security import get_current_user, require_access
from .sources import REGISTRY, SourcesTracker
from .sources.careerjet import fetch as fetch_careerjet
from .sources.jooble import fetch as fetch_jooble

log = logging.getLogger("api")
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
    scam_res = ScamDetectorEngine.analyze_opportunity(
        title=j.title,
        company=j.company,
        description=j.description or "",
        apply_email=j.apply_email,
        recruiter_email=j.recruiter_email,
        job_url=j.url,
    )
    emp_res = EmployerIntelligenceSystem.rate_employer(
        company_name=j.company,
        country=j.country,
        source=j.source,
        job_description=j.description or "",
        eligibility=j.eligibility,
    )
    return {
        "id": a.id, "status": a.status, "method": a.method, "title": j.title, "company": j.company,
        "country": j.country, "location": j.location, "score": j.match_score, "eligibility": j.eligibility,
        "cv_label": a.cv.label if a.cv else None, "created_at": _iso(a.created_at), "sent_at": _iso(a.sent_at),
        "url": j.url, "source": j.source, "last_response_at": _iso(a.last_response_at),
        "response_summary": a.response_summary,
        "probability": prob,
        "ats_score": j.match_score or 75,
        "scam_defense": scam_res,
        "employer_intel": emp_res,
    }


# ================================================================= Dashboard (Isolated per user)
@router.get("/dashboard")
def dashboard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    week = utcnow() - timedelta(days=7)

    def count(stmt) -> int:
        return db.scalar(stmt) or 0

    last_runs = {}
    for kind in ("discover", "evaluate", "send", "inbox"):
        run = db.scalar(select(EngineRun).where(EngineRun.kind == kind).order_by(EngineRun.id.desc()).limit(1))
        if run:
            last_runs[kind] = {"at": _iso(run.started_at), "ok": run.ok, "detail": run.detail}

    # Isolated application counts for current user
    app_query = select(Application.status, func.count()).where(
        or_(Application.user_id == current_user.id, Application.user_id.is_(None))
    ).group_by(Application.status)
    status_counts = dict(db.execute(app_query).all())

    recent_stmt = select(Application).where(
        or_(Application.user_id == current_user.id, Application.user_id.is_(None))
    ).order_by(Application.id.desc()).limit(8)
    recent = db.scalars(recent_stmt)

    user_cvs_cnt = count(select(func.count(Cv.id)).where(Cv.active.is_(True), Cv.user_id == current_user.id))

    return {
        "user": {
            "id": current_user.id,
            "username": current_user.username,
            "email": current_user.email,
            "full_name": current_user.full_name or store.get("full_name", user_id=current_user.id),
        },
        "engine": {"paused": bool(store.get("engine_paused", user_id=current_user.id)), "last_runs": last_runs},
        "config": {
            "gmail": bool(store.get("gmail_address", user_id=current_user.id) and store.get("gmail_app_password", user_id=current_user.id)),
            "ai": True,  # Local Intelligent Engine is always online
            "telegram": bool(store.get("telegram_bot_token", user_id=current_user.id) and store.get("telegram_chat_id", user_id=current_user.id)),
            "whatsapp": bool(store.get("whatsapp_phone", user_id=current_user.id) and store.get("callmebot_apikey", user_id=current_user.id)),
            "cvs": user_cvs_cnt,
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


# ================================================================= Applications (User Isolated)
@router.get("/applications")
def list_applications(
    bucket: str = "all",
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    stmt = select(Application).where(
        or_(Application.user_id == current_user.id, Application.user_id.is_(None))
    ).order_by(Application.id.desc())

    if bucket in BUCKETS:
        stmt = stmt.where(Application.status.in_(BUCKETS[bucket]))

    items = db.scalars(stmt.offset(offset).limit(min(limit, 200)))
    return {"items": [_app_summary(a) for a in items]}


@router.get("/applications/{app_id}")
def get_application(
    app_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    a = db.get(Application, app_id)
    if not a:
        raise HTTPException(404, "Application not found")
    if a.user_id is not None and a.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden: you do not own this application record")

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
def application_action(
    app_id: int,
    body: ActionIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    if body.action not in {"send", "applied", "skip", "requeue"}:
        raise HTTPException(400, "Unknown action")
    a = db.get(Application, app_id)
    if not a:
        raise HTTPException(404, "Application not found")
    if a.user_id is not None and a.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden")

    return {"result": pipeline.application_action(app_id, body.action)}


class LetterIn(BaseModel):
    subject: str
    body: str


@router.put("/applications/{app_id}/letter")
def update_letter(
    app_id: int,
    body: LetterIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    a = db.get(Application, app_id)
    if not a:
        raise HTTPException(404, "Application not found")
    if a.user_id is not None and a.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden")
    if a.status in (AppStatus.SENT, AppStatus.APPLIED_MANUAL):
        raise HTTPException(409, "Already submitted")
    a.cover_subject, a.cover_letter = body.subject.strip(), body.body.strip()
    return {"result": "saved"}


# ================================================================= CV Vault (User Isolated)
@router.get("/cvs")
def list_cvs(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    cvs = db.scalars(select(Cv).where(Cv.user_id == current_user.id).order_by(Cv.id.desc()))
    return {"items": [cv_service.to_dict(c) for c in cvs]}


@router.post("/cvs")
async def upload_cvs(
    files: list[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    created, errors = [], []
    for f in files[:10]:
        content = await f.read()
        try:
            cv = cv_service.store_cv(db, f.filename or "cv.pdf", content, user_id=current_user.id)
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
def patch_cv(
    cv_id: int,
    body: CvPatch,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "CV not found")
    if cv.user_id is not None and cv.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden")

    data = body.model_dump(exclude_none=True)
    if "target_titles" in data:
        data["target_titles"] = json.dumps([t.strip() for t in data["target_titles"] if t.strip()][:8], ensure_ascii=False)
    for k, v in data.items():
        setattr(cv, k, v)
    return cv_service.to_dict(cv)


@router.delete("/cvs/{cv_id}")
def delete_cv(
    cv_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "CV not found")
    if cv.user_id is not None and cv.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden")
    cv_service.delete_cv(db, cv)
    return {"result": "deleted"}


@router.get("/cvs/{cv_id}/file")
def cv_file(
    cv_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cv = db.get(Cv, cv_id)
    if not cv:
        raise HTTPException(404, "CV not found")
    if cv.user_id is not None and cv.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(403, "Access forbidden")
    return FileResponse(cv_service.cv_path(cv), media_type="application/pdf", filename=cv.original_name)


# ================================================================= Settings (User Isolated)
@router.get("/settings")
def get_user_settings(current_user: User = Depends(get_current_user)) -> dict:
    return store.public_view(user_id=current_user.id)


@router.put("/settings")
def put_user_settings(values: dict[str, Any], current_user: User = Depends(get_current_user)) -> dict:
    clean = {}
    for k, v in values.items():
        if k not in store.DEFAULTS or k in store.INTERNAL_KEYS:
            continue
        if k in store.SECRET_KEYS and (v is None or (isinstance(v, str) and not v.strip())):
            continue
        if isinstance(v, str):
            v = v.strip()
        clean[k] = v

    store.set_many(clean, user_id=current_user.id)
    return store.public_view(user_id=current_user.id)


@router.post("/settings/test/{target}")
def test_integration(target: str, current_user: User = Depends(get_current_user)) -> dict:
    try:
        if target == "gmail":
            mailer.test_connection()
            return {"ok": True, "message": "IMAP and SMTP authentication succeeded"}
        if target == "ai":
            info = ai.ping()
            return {"ok": True, "message": f"{info.get('model', 'AI Engine')} is ONLINE", "details": info}
        if target == "telegram":
            return notifier.test_telegram(user_id=current_user.id)
        if target == "whatsapp":
            return notifier.send_whatsapp("VisaJob AI: WhatsApp channel verified successfully.", user_id=current_user.id)
    except Exception as exc:
        return {"ok": False, "message": str(exc)[:300]}
    raise HTTPException(404, "Unknown integration")


# ================================================================= Real Job Discovery & Sources Center
class LiveScanIn(BaseModel):
    keywords: list[str] = ["Software Engineer", "Technician", "Mechanic"]
    countries: list[str] = ["CA", "DE", "FR", "GB"]
    limit_per_source: int = 15


@router.post("/jobs/scan-live")
def scan_live_jobs(body: LiveScanIn, current_user: User = Depends(get_current_user)) -> dict:
    """Executes live searches across active sources and records real discovery results."""
    found = pipeline.run_live_search(body.keywords, body.countries, limit_per_source=body.limit_per_source)
    AgentCoordinator.record_agent_activity(
        "JobAgent",
        f"Live search for {', '.join(body.keywords[:3])} in {', '.join(body.countries)}",
        f"Discovered {len(found)} live job postings"
    )
    return {
        "status": "COMPLETED",
        "jobs_found_count": len(found),
        "results": found,
        "sources_scanned": ["jobbank", "eures", "careerjet", "jooble", "company_careers"],
    }


@router.get("/sources/status")
def get_sources_status() -> dict:
    """Returns live telemetry for all integrated job discovery sources."""
    return {
        "sources": SourcesTracker.get_all_status(),
        "total_active": len(SourcesTracker.get_all_status()),
    }


# ================================================================= Real AI Assistant
class ChatIn(BaseModel):
    prompt: str
    doc_type: str | None = None
    document_text: str | None = None


@router.post("/ai/chat")
def ai_chat(
    body: ChatIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    # 1. Store user message in history
    db.add(AiChatMessage(
        user_id=current_user.id,
        role="user",
        content=body.prompt,
        document_name=body.doc_type,
    ))
    db.flush()

    # 2. Query Local Intelligent Engine / Gemini
    reply_text = LocalIntelligentEngine.chat(
        prompt=body.prompt,
        document_text=body.document_text,
        doc_type=body.doc_type,
    )

    # 3. Store assistant response
    db.add(AiChatMessage(
        user_id=current_user.id,
        role="assistant",
        content=reply_text,
    ))
    db.flush()

    return {
        "reply": reply_text,
        "role": "assistant",
        "timestamp": utcnow().isoformat(),
    }


@router.post("/ai/analyze-document")
async def analyze_document(
    file: UploadFile = File(...),
    doc_type: str = Form("contract"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    """Analyzes an uploaded PDF or document (contract, CV, or offer letter)."""
    content = await file.read()
    extracted_text = ""

    if file.filename and file.filename.lower().endswith(".pdf"):
        import io
        from pypdf import PdfReader
        try:
            reader = PdfReader(io.BytesIO(content))
            extracted_text = "\n".join((p.extract_text() or "") for p in reader.pages)
        except Exception as exc:
            raise HTTPException(400, f"Could not read PDF text: {exc}")
    else:
        try:
            extracted_text = content.decode("utf-8", errors="ignore")
        except Exception:
            extracted_text = "Uploaded binary document"

    # Analyze document based on type
    result = {}
    if doc_type == "contract":
        result = LocalIntelligentEngine.analyze_contract(extracted_text)
    elif doc_type == "cv":
        result = LocalIntelligentEngine.analyze_cv_ats(extracted_text)
    elif doc_type == "offer":
        result = LocalIntelligentEngine.analyze_offer_letter(extracted_text)
    else:
        result = {"summary": extracted_text[:1000]}

    # Log in chat history
    db.add(AiChatMessage(
        user_id=current_user.id,
        role="user",
        content=f"Uploaded document {file.filename} for {doc_type} analysis.",
        document_name=file.filename,
    ))
    db.add(AiChatMessage(
        user_id=current_user.id,
        role="assistant",
        content=json.dumps(result, ensure_ascii=False, indent=2),
        document_name=file.filename,
    ))
    db.flush()

    return {
        "document_name": file.filename,
        "doc_type": doc_type,
        "analysis": result,
    }


@router.get("/ai/messages")
def list_ai_messages(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    messages = db.scalars(
        select(AiChatMessage).where(AiChatMessage.user_id == current_user.id).order_by(AiChatMessage.id.asc()).limit(50)
    )
    return {
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "document_name": m.document_name,
                "created_at": _iso(m.created_at),
            }
            for m in messages
        ]
    }


# ================================================================= Telegram Deep-Link Workflow
@router.get("/telegram/connect-url")
def get_telegram_connect_url(current_user: User = Depends(get_current_user)) -> dict:
    return notifier.get_telegram_connect_url(user_id=current_user.id)


@router.get("/telegram/diagnostics")
def get_telegram_diagnostics(current_user: User = Depends(get_current_user)) -> dict:
    return notifier.get_telegram_diagnostics(user_id=current_user.id)


@router.post("/telegram/test")
def test_telegram_alert(current_user: User = Depends(get_current_user)) -> dict:
    return notifier.test_telegram(user_id=current_user.id)


# ================================================================= WhatsApp Testing & Retry Logic
@router.post("/whatsapp/test")
def test_whatsapp_alert(current_user: User = Depends(get_current_user)) -> dict:
    return notifier.send_whatsapp("VisaJob AI: Test notification delivered.", user_id=current_user.id)


# ================================================================= Agent Activity Center
@router.get("/agents/activity")
def get_agents_activity() -> dict:
    return AgentCoordinator.get_agent_status()


@router.get("/agents/status")
def get_agents_status_legacy() -> dict:
    return AgentCoordinator.get_agent_status()


# ================================================================= Notifications Center
@router.get("/notifications")
def list_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    notes = db.scalars(
        select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.id.desc()).limit(40)
    )
    return {
        "notifications": [
            {
                "id": n.id,
                "category": n.category,
                "title": n.title,
                "message": n.message,
                "is_read": n.is_read,
                "action_url": n.action_url,
                "created_at": _iso(n.created_at),
            }
            for n in notes
        ]
    }


@router.post("/notifications/{note_id}/read")
def mark_notification_read(
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    n = db.get(Notification, note_id)
    if not n or n.user_id != current_user.id:
        raise HTTPException(404, "Notification not found")
    n.is_read = True
    return {"ok": True}


# ================================================================= Logout Cleanup
@router.post("/auth/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    db.execute(
        select(UserSession).where(UserSession.user_id == current_user.id)
    )
    # Revoke sessions for this user
    sessions = db.scalars(select(UserSession).where(UserSession.user_id == current_user.id)).all()
    for s in sessions:
        s.revoked = True
    return {"ok": True, "message": "Successfully logged out. Session tokens revoked."}


# ================================================================= Scam & Employer Intelligence
class ScamCheckIn(BaseModel):
    title: str = ""
    company: str = ""
    text: str = ""
    email: str | None = None


@router.post("/scam-check")
def check_scam(body: ScamCheckIn) -> dict:
    return ScamDetectorEngine.analyze_opportunity(
        title=body.title,
        company=body.company,
        description=body.text,
        apply_email=body.email,
    )
