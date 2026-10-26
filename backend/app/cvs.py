"""CV Vault: storage, text extraction and AI profiling of uploaded CVs."""
from __future__ import annotations

import json
import logging
import os
import re
import uuid

from pypdf import PdfReader
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import ai
from .config import get_settings
from .models import Cv

log = logging.getLogger("cv")
MAX_BYTES = 10 * 1024 * 1024


class CvError(ValueError):
    pass


def extract_text(path: str) -> str:
    reader = PdfReader(path)
    text = "\n".join((page.extract_text() or "") for page in reader.pages)
    return re.sub(r"[ \t]+", " ", text).strip()


def store_cv(db: Session, original_name: str, content: bytes) -> Cv:
    if not content.startswith(b"%PDF"):
        raise CvError(f"{original_name}: not a PDF file")
    if len(content) > MAX_BYTES:
        raise CvError(f"{original_name}: larger than 10 MB")
    stored = f"{uuid.uuid4().hex}.pdf"
    path = os.path.join(get_settings().cv_dir, stored)
    with open(path, "wb") as f:
        f.write(content)
    text = extract_text(path)
    if len(text) < 200:
        os.remove(path)
        raise CvError(f"{original_name}: no readable text (scanned image PDF). Export the CV as a text PDF.")

    cv = Cv(label=os.path.splitext(original_name)[0][:200], original_name=original_name, stored_name=stored, text=text)
    try:
        prof = ai.extract_cv_profile(text)
        cv.language = (prof.language or "en")[:5].lower()
        cv.sector = prof.sector[:200]
        cv.target_titles = json.dumps(prof.target_titles[:6], ensure_ascii=False)
        cv.skills = json.dumps(prof.skills[:40], ensure_ascii=False)
        cv.candidate_name = prof.candidate_name[:200]
        if prof.sector:
            cv.label = f"{prof.sector} ({cv.language.upper()})"[:200]
        _fill_identity(prof)
    except ai.AINotConfigured:
        log.info("AI not configured; CV stored without profile")
    except Exception as exc:
        log.warning("CV profiling failed: %s", exc)
    db.add(cv)
    db.flush()
    return cv


def _fill_identity(prof: ai.CvProfile) -> None:
    from . import settings_store as store

    updates = {}
    if prof.candidate_name and not store.get("full_name"):
        updates["full_name"] = prof.candidate_name
    if prof.phone and not store.get("phone"):
        updates["phone"] = prof.phone
    if updates:
        store.set_many(updates)


def cv_path(cv: Cv) -> str:
    return os.path.join(get_settings().cv_dir, cv.stored_name)


def delete_cv(db: Session, cv: Cv) -> None:
    try:
        os.remove(cv_path(cv))
    except FileNotFoundError:
        pass
    db.delete(cv)


def active_cvs(db: Session) -> list[Cv]:
    return list(db.scalars(select(Cv).where(Cv.active.is_(True))))


def to_dict(cv: Cv) -> dict:
    return {
        "id": cv.id,
        "label": cv.label,
        "original_name": cv.original_name,
        "language": cv.language,
        "sector": cv.sector,
        "target_titles": json.loads(cv.target_titles or "[]"),
        "skills": json.loads(cv.skills or "[]"),
        "candidate_name": cv.candidate_name,
        "active": cv.active,
        "uploaded_at": cv.uploaded_at.isoformat() if cv.uploaded_at else None,
        "chars": len(cv.text or ""),
    }
