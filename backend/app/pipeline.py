"""Core engine: discover -> screen -> queue -> paced sending -> inbox triage -> notifications."""
from __future__ import annotations

import json
import logging
import os
import random
import re
from collections import Counter
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from . import ai, mailer, notifier, pdfgen
from . import settings_store as store
from .config import get_settings
from .cvs import active_cvs, cv_path
from .db import session_scope
from .filters import prescreen
from .models import (
    Application, AppStatus, Cv, Eligibility, EmailEvent, EngineRun, Job, JobStatus, utcnow,
)
from .notifier import esc
from .sources import REGISTRY, RawJob, SourcesTracker
from .sources.base import normalize

log = logging.getLogger("pipeline")

GENERIC_DOMAINS = {
    "gmail.com", "googlemail.com", "yahoo.com", "yahoo.fr", "outlook.com", "hotmail.com", "hotmail.fr",
    "live.com", "icloud.com", "gmx.de", "gmx.net", "web.de", "orange.fr", "free.fr", "aol.com", "proton.me",
    "protonmail.com", "mail.com", "t-online.de", "laposte.net", "sfr.fr",
}
JOB_BOARD_DOMAINS = (
    "linkedin.com", "indeed.com", "glassdoor", "adzuna", "stepstone", "monster", "ziprecruiter", "xing.com",
    "arbeitnow.com", "jooble", "talent.com", "welcometothejungle", "jobbank.gc.ca", "simplyhired",
)
ELIGIBLE = {Eligibility.OPEN_INTERNATIONAL, Eligibility.VISA_SPONSORED}
ELIGIBILITY_LABEL = {
    Eligibility.OPEN_INTERNATIONAL: "Open to international candidates",
    Eligibility.VISA_SPONSORED: "Visa / work-permit sponsorship",
    Eligibility.UNCLEAR: "Eligibility not stated",
}


# ---------------------------------------------------------------- helpers
@contextmanager
def track(kind: str):
    with session_scope() as db:
        run = EngineRun(kind=kind)
        db.add(run)
        db.flush()
        run_id = run.id
    holder = {"detail": ""}
    ok = True
    try:
        yield holder
    except Exception as exc:
        ok = False
        holder["detail"] = f"{type(exc).__name__}: {exc}"
        log.exception("%s failed", kind)
    finally:
        with session_scope() as db:
            run = db.get(EngineRun, run_id)
            run.finished_at = utcnow()
            run.ok = ok
            run.detail = str(holder["detail"])[:2000]


def paused() -> bool:
    return bool(store.get("engine_paused"))


def signature() -> str:
    lines = [store.get("full_name") or "", store.get("phone") or "", store.get("gmail_address") or ""]
    return "\n".join(line for line in lines if line)


def today_start_utc() -> datetime:
    tz = get_settings().tz
    now_local = datetime.now(tz)
    return now_local.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)


def daily_limit() -> int:
    return max(1, min(int(store.get("daily_limit") or 20), get_settings().max_daily_applications))


def sent_today(db: Session) -> int:
    return db.scalar(
        select(func.count(Application.id)).where(
            Application.method == "EMAIL", Application.sent_at >= today_start_utc()
        )
    ) or 0


def search_keywords(db: Session) -> list[str]:
    kws = [k.strip() for k in (store.get("search_keywords") or []) if k.strip()]
    if not kws:
        for cv in active_cvs(db):
            kws.extend(json.loads(cv.target_titles or "[]"))
    seen, out = set(), []
    for k in kws:
        n = normalize(k)
        if n and n not in seen:
            seen.add(n)
            out.append(k)
    return out[:8]


def _job_dict(job: Job) -> dict:
    return {
        "source": job.source, "external_id": job.external_id, "title": job.title, "company": job.company,
        "country": job.country, "location": job.location, "description": job.description or "",
        "international_hint": job.international_hint,
    }


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ---------------------------------------------------------------- 1. discovery
def discover() -> str:
    with track("discover") as t:
        if paused():
            t["detail"] = "paused"
            return t["detail"]
        with session_scope() as db:
            keywords = search_keywords(db)
        if not keywords:
            t["detail"] = "No search keywords: upload a CV or set keywords in Settings"
            return t["detail"]
        countries = store.get("target_countries") or []
        enabled = store.get("sources_enabled") or []
        stats = {}
        for name in enabled:
            fn = REGISTRY.get(name)
            if not fn:
                continue
            try:
                raw = fn(keywords, countries)
                stored = _store_jobs(raw)
                SourcesTracker.record_scan(name, count=len(raw))
                stats[name] = stored
            except Exception as exc:
                log.warning("source %s crashed: %s", name, exc)
                SourcesTracker.record_scan(name, count=0, error=str(exc))
                stats[name] = f"error: {exc}"[:120]
                continue
        t["detail"] = json.dumps(stats)
        return t["detail"]
    return "failed"


def _store_jobs(raw: list[RawJob]) -> int:
    new = 0
    with session_scope() as db:
        for rj in raw:
            if not rj.title or not rj.external_id:
                continue
            fp = rj.fingerprint
            exists = db.scalar(select(Job.id).where(
                or_(Job.fingerprint == fp, (Job.source == rj.source) & (Job.external_id == rj.external_id))
            ))
            if exists:
                continue
            db.add(Job(
                source=rj.source, external_id=rj.external_id[:300], fingerprint=fp, url=rj.url, title=rj.title[:500],
                company=rj.company[:300], country=rj.country, location=rj.location[:300], description=rj.description,
                apply_email=rj.apply_email, international_hint=rj.international_hint, posted_at=rj.posted_at,
            ))
            db.flush()
            new += 1
    return new


# ---------------------------------------------------------------- 2. screening
def evaluate_pending(limit: int = 25) -> str:
    with track("evaluate") as t:
        if paused():
            t["detail"] = "paused"
            return t["detail"]
        with session_scope() as db:
            cvs = [
                {"id": c.id, "label": c.label, "language": c.language, "text": c.text} for c in active_cvs(db)
            ]
            job_ids = list(db.scalars(
                select(Job.id).where(Job.status == JobStatus.NEW).order_by(Job.discovered_at.desc()).limit(limit)
            ))
        if not cvs:
            t["detail"] = "No active CV in the vault"
            return t["detail"]
        counts: Counter = Counter()
        for jid in job_ids:
            try:
                counts[_evaluate_one(jid, cvs)] += 1
            except ai.AINotConfigured as exc:
                t["detail"] = str(exc)
                return t["detail"]
            except Exception as exc:
                counts["error"] += 1
                with session_scope() as db:
                    job = db.get(Job, jid)
                    job.status, job.error = JobStatus.ERROR, str(exc)[:1000]
        t["detail"] = json.dumps(counts)
        return t["detail"]
    return "failed"


def _evaluate_one(job_id: int, cvs: list[dict]) -> str:
    with session_scope() as db:
        job = db.get(Job, job_id)
        jd = _job_dict(job)
    pre = prescreen(jd["title"], jd["company"], jd["description"])
    if pre:
        with session_scope() as db:
            job = db.get(Job, job_id)
            job.status, job.eligibility, job.eligibility_evidence = JobStatus.INELIGIBLE, pre[0], pre[1]
            job.evaluated_at = utcnow()
        return "rule_rejected"

    ev = ai.evaluate_job(jd, cvs)
    valid_ids = {c["id"] for c in cvs}
    allow_unclear = bool(store.get("allow_unclear_eligibility"))
    min_score = int(store.get("min_match_score") or 70)
    with session_scope() as db:
        job = db.get(Job, job_id)
        job.eligibility = ev.eligibility.value
        job.eligibility_evidence = ev.eligibility_evidence[:2000]
        job.language = (ev.language or "en")[:5].lower()
        job.match_score = ev.match_score
        job.cv_id = ev.best_cv_id if ev.best_cv_id in valid_ids else None
        job.missing_skills = json.dumps(ev.missing_skills[:15], ensure_ascii=False)
        job.summary = ev.summary[:1000]
        job.recruiter_name = ev.recruiter_name
        job.recruiter_email = (ev.recruiter_email or None) and ev.recruiter_email.lower()
        if not job.apply_email and ev.apply_email and ev.apply_email.lower() in (job.description or "").lower():
            job.apply_email = ev.apply_email.lower()
        job.evaluated_at = utcnow()

        eligible = job.eligibility in ELIGIBLE or (job.eligibility == Eligibility.UNCLEAR and allow_unclear)
        if not eligible:
            job.status = JobStatus.INELIGIBLE
            return "ineligible"
        if job.cv_id is None or ev.match_score < min_score:
            job.status = JobStatus.LOW_MATCH
            return "low_match"
        job.status = JobStatus.MATCHED
        db.flush()
        app_id = _create_application(db, job)
    _after_create(app_id)
    return "matched"


def _create_application(db: Session, job: Job) -> int:
    existing = db.scalar(select(Application.id).where(Application.job_id == job.id))
    if existing:
        return existing
    method = "EMAIL" if job.apply_email else "MANUAL"
    cc = job.recruiter_email if job.recruiter_email and job.recruiter_email != job.apply_email else None
    status = AppStatus.QUEUED if method == "EMAIL" and store.get("auto_send") else AppStatus.AWAITING_USER
    app = Application(job_id=job.id, cv_id=job.cv_id, method=method, status=status, to_email=job.apply_email, cc_email=cc)
    db.add(app)
    db.flush()
    return app.id


def _ensure_cover_letter(db: Session, app: Application) -> None:
    if app.cover_letter:
        return
    cv = app.cv or db.get(Cv, app.cv_id) if app.cv_id else None
    if cv is None:
        raise RuntimeError("CV no longer available")
    letter = ai.write_cover_letter(_job_dict(app.job), cv.text, app.job.language or cv.language, signature())
    app.cover_subject, app.cover_letter = letter.subject[:300], letter.body


def _after_create(app_id: int) -> None:
    """For applications needing the user, prepare the letter and send a review card."""
    with session_scope() as db:
        app = db.get(Application, app_id)
        if app.status != AppStatus.AWAITING_USER:
            return
        try:
            _ensure_cover_letter(db, app)
        except Exception as exc:
            app.error = f"Cover letter: {exc}"[:500]
        if not store.get("notify_manual_review"):
            return
        job, cv = app.job, app.cv
        text = (
            f"<b>Match {job.match_score}%</b> · {esc(ELIGIBILITY_LABEL.get(job.eligibility, job.eligibility))}\n"
            f"<b>{esc(job.title)}</b>\n{esc(job.company)} · {esc(job.location)} ({job.country})\n"
            f"CV: {esc(cv.label if cv else '-')}\n"
        )
        if job.eligibility_evidence:
            text += f"Evidence: <i>“{esc(job.eligibility_evidence[:300])}”</i>\n"
        if app.method == "MANUAL":
            text += "\nPortal application: the cover letter is ready in the app. Submit on the employer page, then confirm."
            buttons = [[("Open posting", f"url:{job.url}")], [("Applied", f"app:{app.id}:applied"), ("Skip", f"app:{app.id}:skip")]]
        else:
            text += f"\nEmail application to {esc(app.to_email)}. Review the letter in the app or send now."
            buttons = [[("Send now", f"app:{app.id}:send"), ("Skip", f"app:{app.id}:skip")]]
        notifier.send(text, buttons)


# ---------------------------------------------------------------- 3. paced sending
def send_due() -> str:
    if paused():
        return "paused"
    with session_scope() as db:
        limit = daily_limit()
        if sent_today(db) >= limit:
            return "daily limit reached"
        last = _aware(db.scalar(select(func.max(Application.sent_at)).where(Application.method == "EMAIL")))
        interval = 86400 / limit
        if last and (utcnow() - last).total_seconds() < interval * random.uniform(0.75, 1.25):
            return "pacing"
        app_id = db.scalar(
            select(Application.id).join(Job).where(Application.status == AppStatus.QUEUED)
            .order_by(Job.match_score.desc(), Application.created_at).limit(1)
        )
    if not app_id:
        return "queue empty"
    with track("send") as t:
        t["detail"] = send_application(app_id)
        return t["detail"]
    return "failed"


def send_application(app_id: int, force: bool = False) -> str:
    with session_scope() as db:
        app = db.get(Application, app_id)
        if app is None:
            return "Application not found"
        if app.status in (AppStatus.SENT, AppStatus.APPLIED_MANUAL):
            return "Already sent"
        if app.method != "EMAIL" or not app.to_email:
            return "This application must be submitted on the employer portal"
        if sent_today(db) >= daily_limit():
            return f"Daily limit of {daily_limit()} reached"
        try:
            _ensure_cover_letter(db, app)
            cv = app.cv
            name = re.sub(r"[^A-Za-z0-9]+", "_", store.get("full_name") or "CV").strip("_")
            msg_id = mailer.send_email(
                to=app.to_email, cc=app.cc_email, subject=app.cover_subject or f"Application: {app.job.title}",
                body=app.cover_letter or "", attachment_path=cv_path(cv) if cv else None,
                attachment_name=f"CV_{name}_{(cv.language if cv else 'en').upper()}.pdf",
            )
        except mailer.MailNotConfigured as exc:
            return str(exc)
        except Exception as exc:
            app.status, app.error = AppStatus.FAILED, str(exc)[:1000]
            return f"Failed: {exc}"
        app.status, app.message_id, app.sent_at, app.error = AppStatus.SENT, msg_id, utcnow(), None
        return f"Sent to {app.to_email}"


def follow_ups(max_per_day: int = 5) -> str:
    if paused():
        return "paused"
    days = int(store.get("follow_up_days") or 8)
    cutoff = utcnow() - timedelta(days=days)
    sent = 0
    with session_scope() as db:
        apps = list(db.scalars(
            select(Application).where(
                Application.status == AppStatus.SENT, Application.method == "EMAIL",
                Application.sent_at < cutoff, Application.follow_up_sent_at.is_(None),
                Application.last_response_at.is_(None),
            ).limit(max_per_day)
        ))
        for app in apps:
            try:
                body = ai.write_follow_up(_job_dict(app.job), app.job.language or "en", signature())
                mailer.send_email(app.to_email, f"Re: {app.cover_subject}", body, in_reply_to=app.message_id)
                app.follow_up_sent_at = utcnow()
                sent += 1
            except Exception as exc:
                log.warning("follow-up %s failed: %s", app.id, exc)
    return f"{sent} follow-ups"


# ---------------------------------------------------------------- 4. inbox triage
CATEGORY_STATUS = {
    "AUTO_ACK": AppStatus.ACKNOWLEDGED,
    "REJECTION": AppStatus.REJECTED,
    "INTERVIEW_INVITE": AppStatus.INTERVIEW,
    "OFFER": AppStatus.OFFER,
    "POSITIVE_NEXT_STEP": AppStatus.IN_PROGRESS,
    "INFO_REQUEST": AppStatus.IN_PROGRESS,
}
NOTIFY = {"INTERVIEW_INVITE", "OFFER", "POSITIVE_NEXT_STEP", "INFO_REQUEST"}

NOTIF_TEXTS = {
    "ar": {
        "INTERVIEW_INVITE": "🎉 دعوة لمقابلة عمل (Interview Invitation)",
        "OFFER": "🏆 عرض عمل رسمي (Job Offer)",
        "POSITIVE_NEXT_STEP": "✨ رد إيجابي من المشغّل (Positive Step)",
        "INFO_REQUEST": "📩 طلب معلومات إضافية من الشركة",
        "FROM": "المرسل",
        "SUBJECT": "الموضوع",
        "PROPOSED_REPLY": "الرد المقترح آلياً بالاستناد إلى السيرة الذاتية:",
        "SEND_REPLY": "إرسال الرد",
        "DISMISS": "تجاهل",
        "REVIEW_LETTER": "مراجعة وإرسال الرسالة",
        "SKIP": "تخطي",
        "PORTAL_READY": "رسالة التقديم جاهزة داخل التطبيق. قدّم في بوابة الشركة ثم أكّد التقديم.",
        "EMAIL_READY": "ترشح عبر البريد الإلكتروني. راجع الرسالة في التطبيق أو أرسل فوراً.",
    },
    "fr": {
        "INTERVIEW_INVITE": "🎉 Invitation à un entretien d'embauche",
        "OFFER": "🏆 Offre d'emploi officielle reçue",
        "POSITIVE_NEXT_STEP": "✨ Réponse positive de l'employeur",
        "INFO_REQUEST": "📩 L'employeur demande des informations complémentaires",
        "FROM": "De",
        "SUBJECT": "Objet",
        "PROPOSED_REPLY": "Réponse proposée (basée strictement sur votre CV) :",
        "SEND_REPLY": "Envoyer la réponse",
        "DISMISS": "Ignorer",
        "REVIEW_LETTER": "Vérifier & Envoyer",
        "SKIP": "Passer",
        "PORTAL_READY": "La lettre de motivation est prête dans l'app. Postulez sur le portail employeur puis confirmez.",
        "EMAIL_READY": "Candidature par e-mail. Vérifiez la lettre dans l'application ou envoyez maintenant.",
    },
    "en": {
        "INTERVIEW_INVITE": "🎉 Interview invitation",
        "OFFER": "🏆 Job offer received",
        "POSITIVE_NEXT_STEP": "✨ Positive response from employer",
        "INFO_REQUEST": "📩 Employer requests additional information",
        "FROM": "From",
        "SUBJECT": "Subject",
        "PROPOSED_REPLY": "Proposed reply (strictly grounded in CV):",
        "SEND_REPLY": "Send reply",
        "DISMISS": "Dismiss",
        "REVIEW_LETTER": "Send now",
        "SKIP": "Skip",
        "PORTAL_READY": "Portal application: the cover letter is ready in the app. Submit on the employer page, then confirm.",
        "EMAIL_READY": "Email application ready. Review the letter in the app or send now.",
    },
}

TRACKED = [
    AppStatus.SENT, AppStatus.APPLIED_MANUAL, AppStatus.ACKNOWLEDGED, AppStatus.IN_PROGRESS, AppStatus.INTERVIEW,
]


def _domain(addr: str | None) -> str:
    return (addr or "").split("@")[-1].lower()


def check_inbox() -> str:
    with track("inbox") as t:
        own = (store.get("gmail_address") or "").lower()
        last_uid = int(store.get("imap_last_uid") or 0)
        mails = mailer.fetch_new(last_uid)
        if not mails:
            t["detail"] = "no new mail"
            return t["detail"]
        with session_scope() as db:
            apps = list(db.scalars(
                select(Application).where(
                    Application.status.in_(TRACKED), Application.created_at >= utcnow() - timedelta(days=150)
                )
            ))
            idx = [
                {
                    "id": a.id, "msgid": a.message_id, "to": (a.to_email or "").lower(), "cc": (a.cc_email or "").lower(),
                    "company": normalize(a.job.company),
                }
                for a in apps
            ]
        handled = 0
        max_uid = last_uid
        for mail in mails:
            max_uid = max(max_uid, mail.uid)
            if mail.from_addr == own:
                continue
            app_id = _match(mail, idx)
            if app_id is None:
                continue
            try:
                _triage(mail, app_id)
                handled += 1
            except ai.AINotConfigured:
                max_uid = min(max_uid, mail.uid - 1)
                break
            except Exception as exc:
                log.warning("triage failed for uid %s: %s", mail.uid, exc)
        store.put("imap_last_uid", max_uid)
        t["detail"] = f"{len(mails)} scanned, {handled} matched"
        return t["detail"]
    return "failed"


def _match(mail: mailer.InboundMail, idx: list[dict]) -> int | None:
    refs = set(mail.references)
    for a in idx:
        if a["msgid"] and a["msgid"] in refs:
            return a["id"]
    dom = _domain(mail.from_addr)
    if any(b in dom for b in JOB_BOARD_DOMAINS):
        return None
    for a in idx:
        if mail.from_addr and mail.from_addr in (a["to"], a["cc"]):
            return a["id"]
    if dom not in GENERIC_DOMAINS:
        for a in idx:
            if dom and dom in (_domain(a["to"]), _domain(a["cc"])):
                return a["id"]
    header = normalize(f"{mail.from_name} {dom.split('.')[0]} {mail.subject}")
    for a in idx:
        if len(a["company"]) >= 4 and a["company"] in header:
            return a["id"]
    return None


def _triage(mail: mailer.InboundMail, app_id: int) -> None:
    with session_scope() as db:
        if db.scalar(select(EmailEvent.id).where(EmailEvent.imap_uid == mail.uid)):
            return
        app = db.get(Application, app_id)
        job = app.job
        cv_text = app.cv.text if app.cv else ""
        ctx = {"title": job.title, "company": job.company, "country": job.country}
        jd = _job_dict(job)
    email_text = f"From: {mail.from_name} <{mail.from_addr}>\nSubject: {mail.subject}\n\n{mail.body}"
    tri = ai.triage_email(email_text, ctx, cv_text, signature())
    cat = tri.category.value

    with session_scope() as db:
        ev = EmailEvent(
            imap_uid=mail.uid, application_id=app_id, from_addr=mail.from_addr, subject=mail.subject[:1000],
            message_id=mail.message_id, received_at=mail.date or utcnow(), category=cat,
            evidence=tri.evidence[:2000], summary=tri.summary[:2000],
            draft_reply=tri.draft_reply if tri.needs_reply else None,
        )
        db.add(ev)
        app = db.get(Application, app_id)
        if cat in CATEGORY_STATUS:
            new_status = CATEGORY_STATUS[cat]
            # never downgrade an interview/offer to an acknowledgement
            if not (new_status == AppStatus.ACKNOWLEDGED and app.status in (AppStatus.INTERVIEW, AppStatus.IN_PROGRESS)):
                app.status = new_status
            app.last_response_at = utcnow()
            app.response_summary = tri.summary[:1000]
        db.flush()
        event_id = ev.id

    if cat not in NOTIFY:
        return
    lang = (store.get("notification_language") or "ar").lower()
    strings = NOTIF_TEXTS.get(lang, NOTIF_TEXTS["ar"])
    headline = strings.get(cat, cat)
    text = (
        f"<b>{headline}</b>\n<b>{esc(ctx['title'])}</b> — {esc(ctx['company'])} ({ctx['country']})\n"
        f"{strings['FROM']}: {esc(mail.from_addr)}\n{strings['SUBJECT']}: {esc(mail.subject)}\n\n"
        f"<i>“{esc(tri.evidence[:500])}”</i>\n\n{esc(tri.summary)}"
    )
    if tri.interview_datetime:
        text += f"\n\nDate: <b>{esc(tri.interview_datetime)}</b>"
    buttons = None
    if tri.needs_reply and tri.draft_reply:
        text += f"\n\n<b>{strings['PROPOSED_REPLY']}</b>\n{esc(tri.draft_reply[:1500])}"
        buttons = [[(strings['SEND_REPLY'], f"reply:{event_id}:send"), (strings['DISMISS'], f"reply:{event_id}:dismiss")]]
    notifier.send(text, buttons, whatsapp=True)

    if cat == "INTERVIEW_INVITE":
        _interview_pack(event_id, jd, email_text, cv_text)


def _interview_pack(event_id: int, jd: dict, email_text: str, cv_text: str) -> None:
    try:
        brief = ai.research_company(jd["company"], jd["country"])
        prep = ai.interview_prep(jd, email_text, cv_text, brief)
        safe = re.sub(r"[^A-Za-z0-9]+", "_", jd["company"])[:40]
        path = os.path.join(get_settings().reports_dir, f"interview_{event_id}_{safe}.pdf")
        pdfgen.build_interview_pdf(path, jd["title"], jd["company"], prep)
        with session_scope() as db:
            db.get(EmailEvent, event_id).prep_pdf = os.path.basename(path)
        notifier.send_document(path, f"<b>Interview preparation</b> — {esc(jd['company'])}")
    except Exception as exc:
        log.warning("interview pack failed: %s", exc)


# ---------------------------------------------------------------- 5. callbacks & actions
def handle_callback(data: str) -> str:
    parts = data.split(":")
    if len(parts) != 3 or not parts[1].isdigit():
        return "Unknown action"
    kind, oid, action = parts[0], int(parts[1]), parts[2]
    if kind == "app":
        return application_action(oid, action)
    if kind == "reply":
        return reply_action(oid, action)
    return "Unknown action"


def application_action(app_id: int, action: str) -> str:
    if action == "send":
        return send_application(app_id, force=True)
    with session_scope() as db:
        app = db.get(Application, app_id)
        if app is None:
            return "Application not found"
        if action == "applied":
            app.status, app.sent_at = AppStatus.APPLIED_MANUAL, utcnow()
            return "Marked as applied"
        if action == "skip":
            app.status = AppStatus.SKIPPED
            return "Skipped"
        if action == "requeue" and app.method == "EMAIL":
            app.status, app.error = AppStatus.QUEUED, None
            return "Back in queue"
    return "Unknown action"


def reply_action(event_id: int, action: str, body_override: str | None = None) -> str:
    with session_scope() as db:
        ev = db.get(EmailEvent, event_id)
        if ev is None:
            return "Message not found"
        if ev.reply_sent:
            return "Reply already sent"
        if action == "dismiss":
            ev.draft_reply = None
            return "Dismissed"
        if action != "send":
            return "Unknown action"
        body = body_override or ev.draft_reply
        if not body:
            return "No reply drafted"
        subject = ev.subject if ev.subject.lower().startswith("re:") else f"Re: {ev.subject}"
        try:
            mailer.send_email(ev.from_addr, subject, body, in_reply_to=ev.message_id)
        except Exception as exc:
            return f"Failed: {exc}"[:180]
        ev.reply_sent = True
        return f"Reply sent to {ev.from_addr}"


# ---------------------------------------------------------------- 6. analytics
def skill_gaps(db: Session, days: int = 30, top: int = 10) -> list[dict]:
    since = utcnow() - timedelta(days=days)
    rows = db.execute(
        select(Job.missing_skills, Job.country).where(
            Job.evaluated_at >= since, Job.status.in_([JobStatus.LOW_MATCH, JobStatus.MATCHED]),
            Job.eligibility.in_(list(ELIGIBLE)),
        )
    ).all()
    counter: Counter = Counter()
    countries: dict[str, Counter] = {}
    for skills_json, country in rows:
        for s in json.loads(skills_json or "[]"):
            key = s.strip()
            if not key:
                continue
            counter[key.lower()] += 1
            countries.setdefault(key.lower(), Counter())[country] += 1
    return [
        {"skill": k, "count": n, "countries": [c for c, _ in countries[k].most_common(3)]}
        for k, n in counter.most_common(top)
    ]


def weekly_report() -> str:
    with session_scope() as db:
        since = utcnow() - timedelta(days=7)
        found = db.scalar(select(func.count(Job.id)).where(Job.discovered_at >= since)) or 0
        matched = db.scalar(select(func.count(Job.id)).where(Job.discovered_at >= since, Job.status == JobStatus.MATCHED)) or 0
        sent = db.scalar(select(func.count(Application.id)).where(Application.sent_at >= since)) or 0
        positives = db.scalar(select(func.count(EmailEvent.id)).where(
            EmailEvent.received_at >= since, EmailEvent.category.in_(list(NOTIFY)))) or 0
        gaps = skill_gaps(db, days=7, top=6)
    lines = [
        "<b>Weekly report</b>",
        f"Jobs analysed: {found}", f"Eligible matches: {matched}", f"Applications submitted: {sent}",
        f"Positive responses: {positives}",
    ]
    if gaps:
        lines.append("\n<b>Skill gaps blocking eligible offers</b>")
        lines += [f"• {esc(g['skill'])} — {g['count']} offers ({', '.join(g['countries'])})" for g in gaps]
    notifier.send("\n".join(lines))
    return "sent"


def run_live_search(keywords: list[str], countries: list[str], limit_per_source: int = 15) -> list[dict]:
    """Executes an on-demand live search across real job boards and stores results immediately."""
    results = []
    for name, fn in REGISTRY.items():
        if name not in (store.get("sources_enabled") or ["jobbank", "eures", "careerjet", "jooble", "company_careers"]):
            continue
        try:
            raw_jobs = fn(keywords, countries, limit=limit_per_source) if "limit" in fn.__code__.co_varnames else fn(keywords, countries)
            _store_jobs(raw_jobs)
            SourcesTracker.record_scan(name, count=len(raw_jobs))
            for r in raw_jobs:
                results.append({
                    "source": r.source,
                    "title": r.title,
                    "company": r.company,
                    "country": r.country,
                    "location": r.location,
                    "url": r.url,
                    "apply_email": r.apply_email,
                    "international_hint": r.international_hint,
                    "discovered_at": utcnow().isoformat(),
                })
        except Exception as exc:
            log.warning("Live scan error on source %s: %s", name, exc)
            SourcesTracker.record_scan(name, count=0, error=str(exc))
    return results
