"""Gemini (Pro tier) integration: job screening, cover letters, email triage, interview prep.

Every generation is grounded strictly in the uploaded CV text. The model is instructed never
to invent experience, certificates, dates or skills.
"""
from __future__ import annotations

import json
import logging
import re
import time
from enum import Enum
from typing import TypeVar

from google import genai
from google.genai import types
from pydantic import BaseModel, Field

from . import settings_store as store

log = logging.getLogger("ai")
T = TypeVar("T", bound=BaseModel)

_model_cache: dict[str, str] = {}


class AINotConfigured(RuntimeError):
    pass


# ---------------------------------------------------------------- schemas
class EligibilityCat(str, Enum):
    OPEN_INTERNATIONAL = "OPEN_INTERNATIONAL"
    VISA_SPONSORED = "VISA_SPONSORED"
    REQUIRES_WORK_PERMIT = "REQUIRES_WORK_PERMIT"
    GOVERNMENT_OR_CITIZENSHIP = "GOVERNMENT_OR_CITIZENSHIP"
    UNCLEAR = "UNCLEAR"


class JobEvaluation(BaseModel):
    eligibility: EligibilityCat
    eligibility_evidence: str = Field(description="Verbatim quote from the posting supporting the eligibility decision, or empty string")
    language: str = Field(description="ISO 639-1 code of the posting language")
    best_cv_id: int | None = Field(description="id of the most suitable CV, null if none fits")
    match_score: int = Field(ge=0, le=100)
    matched_requirements: list[str]
    missing_skills: list[str] = Field(description="Explicit requirements of the posting that the chosen CV does not show")
    apply_email: str | None = Field(description="Application email address only if explicitly written in the posting")
    recruiter_name: str | None
    recruiter_email: str | None
    summary: str = Field(description="One sentence summary of the role")


class CoverLetter(BaseModel):
    subject: str
    body: str


class EmailCategory(str, Enum):
    AUTO_ACK = "AUTO_ACK"
    REJECTION = "REJECTION"
    INTERVIEW_INVITE = "INTERVIEW_INVITE"
    OFFER = "OFFER"
    POSITIVE_NEXT_STEP = "POSITIVE_NEXT_STEP"
    INFO_REQUEST = "INFO_REQUEST"
    UNRELATED = "UNRELATED"


class EmailTriage(BaseModel):
    category: EmailCategory
    evidence: str = Field(description="Verbatim sentence from the email that justifies the category")
    summary: str
    interview_datetime: str | None
    needs_reply: bool
    draft_reply: str = Field(description="Professional reply in the email's language, empty if no reply needed")


class QA(BaseModel):
    question: str
    suggested_answer: str


class InterviewPrep(BaseModel):
    company_overview: str
    role_focus: list[str]
    questions: list[QA]
    questions_to_ask: list[str]
    logistics: str


class CvProfile(BaseModel):
    candidate_name: str
    phone: str
    language: str = Field(description="ISO 639-1 code of the CV language")
    sector: str
    target_titles: list[str] = Field(description="Up to 6 job titles this CV directly qualifies for, wording as used by employers")
    skills: list[str]


# ---------------------------------------------------------------- client
def _client() -> genai.Client:
    key = store.get("ai_api_key")
    if not key:
        raise AINotConfigured("AI API key is not configured")
    return genai.Client(api_key=key)


def list_models() -> list[str]:
    names = []
    for m in _client().models.list():
        actions = getattr(m, "supported_actions", None) or []
        if "generateContent" in actions:
            names.append(m.name.removeprefix("models/"))
    return sorted(names)


def _version_key(name: str) -> tuple:
    nums = [int(x) for x in re.findall(r"\d+", name)[:2]]
    stable = 0 if ("preview" in name or "exp" in name) else 1
    return (*nums, stable)


def resolve_model() -> str:
    configured = store.get("ai_model")
    if configured:
        return configured
    key = store.get("ai_api_key") or ""
    if key in _model_cache:
        return _model_cache[key]
    excluded = ("tts", "image", "vision", "embedding", "audio", "live", "lite", "computer")
    candidates = [n for n in list_models() if "gemini" in n and "pro" in n and not any(x in n for x in excluded)]
    if not candidates:
        raise AINotConfigured("No Gemini Pro model available for this API key")
    best = max(candidates, key=_version_key)
    _model_cache[key] = best
    log.info("Auto-selected model %s", best)
    return best


def _generate(prompt: str, system: str, schema: type[T] | None = None, temperature: float = 0.2,
              search: bool = False) -> T | str:
    client = _client()
    model = resolve_model()
    cfg = types.GenerateContentConfig(system_instruction=system, temperature=temperature)
    if schema is not None:
        cfg.response_mime_type = "application/json"
        cfg.response_schema = schema
    if search:
        cfg.tools = [types.Tool(google_search=types.GoogleSearch())]
    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            resp = client.models.generate_content(model=model, contents=prompt, config=cfg)
            if schema is None:
                return (resp.text or "").strip()
            if isinstance(resp.parsed, schema):
                return resp.parsed
            return schema.model_validate_json(resp.text or "{}")
        except Exception as exc:  # network / quota / transient
            last_exc = exc
            log.warning("AI call failed (attempt %s): %s", attempt + 1, exc)
            time.sleep(4 * (attempt + 1))
    raise RuntimeError(f"AI generation failed: {last_exc}")


def ping() -> dict[str, Any]:
    key = store.get("ai_api_key")
    if key:
        try:
            model = resolve_model()
            _client()
            return {"ok": True, "provider": "gemini", "model": model, "status": "ONLINE"}
        except Exception as exc:
            log.warning("Gemini ping failed (%s), falling back to LocalIntelligentEngine", exc)
    from .local_ai import LocalIntelligentEngine
    res = LocalIntelligentEngine.ping()
    return {"ok": True, **res}


# ---------------------------------------------------------------- tasks
_SCREEN_SYSTEM = """You are a strict international recruitment screener.
The candidate lives in Tunisia, holds Tunisian citizenship only, and has NO existing right to work
in the EU/EEA, Switzerland, the UK, Canada or the USA.

Eligibility categories:
- OPEN_INTERNATIONAL: the posting or source explicitly states that candidates from abroad / international
  candidates / foreign workers are accepted.
- VISA_SPONSORED: the posting explicitly mentions visa sponsorship, work permit support, relocation for
  foreign hires, LMIA, EU Blue Card, H-1B, H-2B, TN, or similar.
- REQUIRES_WORK_PERMIT: the posting requires existing authorization to work / residency / "no sponsorship".
- GOVERNMENT_OR_CITIZENSHIP: public sector job or requires citizenship, security clearance, or nationality.
- UNCLEAR: nothing explicit either way.
Never assume a job is open to foreigners without explicit evidence. Quote the evidence verbatim.

Matching: compare the posting with each CV. Use ONLY facts written in the CVs. Score 0-100 how well the
best CV satisfies the mandatory requirements (licenses, certifications, years, languages, tools).
A missing mandatory license or certification caps the score at 40."""


def evaluate_job(job: dict, cvs: list[dict]) -> JobEvaluation:
    cv_block = "\n\n".join(
        f"### CV id={c['id']} label={c['label']} language={c['language']}\n{c['text'][:12000]}" for c in cvs
    )
    prompt = (
        f"## JOB POSTING\nSource: {job['source']}\nSource note: {job.get('international_hint') or 'none'}\n"
        f"Title: {job['title']}\nCompany: {job['company']}\nCountry: {job['country']}\nLocation: {job['location']}\n"
        f"Description:\n{job['description'][:15000]}\n\n## CANDIDATE CVS\n{cv_block}"
    )
    try:
        if not store.get("ai_api_key"):
            from .local_ai import LocalIntelligentEngine
            return LocalIntelligentEngine.evaluate_job(job, cvs)
        return _generate(prompt, _SCREEN_SYSTEM, JobEvaluation)  # type: ignore[return-value]
    except Exception as exc:
        log.warning("Gemini evaluate_job error (%s), fallback to LocalIntelligentEngine", exc)
        from .local_ai import LocalIntelligentEngine
        return LocalIntelligentEngine.evaluate_job(job, cvs)


_WRITER_SYSTEM = """You write concise, professional job application emails.
Absolute rules:
- Use ONLY facts present in the CV text. Do not add skills, years, employers, certificates or achievements
  that are not written in the CV. Do not exaggerate.
- Write in the requested language.
- No placeholders, no brackets, no template markers. Max 190 words for the body.
- Mention that the CV is attached. Mention the candidate is based in Tunisia and available to relocate.
- End with the signature block provided, unchanged."""


def write_cover_letter(job: dict, cv_text: str, language: str, signature: str) -> CoverLetter:
    prompt = (
        f"Language: {language}\nPosition: {job['title']}\nCompany: {job['company']}\n"
        f"Location: {job['location']} ({job['country']})\nReference: {job.get('external_id', '')}\n"
        f"Posting:\n{job['description'][:8000]}\n\nCV TEXT:\n{cv_text[:12000]}\n\nSIGNATURE:\n{signature}"
    )
    try:
        if not store.get("ai_api_key"):
            from .local_ai import LocalIntelligentEngine
            return LocalIntelligentEngine.write_cover_letter(job, cv_text, language, signature)
        return _generate(prompt, _WRITER_SYSTEM, CoverLetter, temperature=0.4)  # type: ignore[return-value]
    except Exception as exc:
        log.warning("Gemini write_cover_letter error (%s), fallback to LocalIntelligentEngine", exc)
        from .local_ai import LocalIntelligentEngine
        return LocalIntelligentEngine.write_cover_letter(job, cv_text, language, signature)


def write_follow_up(job: dict, language: str, signature: str) -> str:
    if store.get("ai_api_key"):
        try:
            prompt = (
                f"Language: {language}\nWrite a 3-4 sentence polite follow-up on my application for '{job['title']}' "
                f"at {job['company']}, sent about a week ago. Reaffirm interest, ask about next steps. "
                f"Plain text body only, end with:\n{signature}"
            )
            return _generate(prompt, _WRITER_SYSTEM, temperature=0.4)  # type: ignore[return-value]
        except Exception as exc:
            log.warning("Remote write_follow_up failed (%s), fallback to LocalIntelligentEngine", exc)
    from .local_ai import LocalIntelligentEngine
    return LocalIntelligentEngine.write_follow_up(job, language, signature)


_TRIAGE_SYSTEM = """You classify emails received in reply to job applications.
Categories: AUTO_ACK (automatic receipt confirmation), REJECTION, INTERVIEW_INVITE (explicit invitation to an
interview/call/test with the employer), OFFER (job offer / contract), POSITIVE_NEXT_STEP (explicit progression
such as shortlisted, asked for availability, documents for hiring), INFO_REQUEST (employer asks a question),
UNRELATED (newsletters, job alerts, marketing, tips, platform notifications).
Be conservative: only INTERVIEW_INVITE/OFFER/POSITIVE_NEXT_STEP when the email itself explicitly says so.
If a reply is needed, draft it using only facts from the CV, in the language of the email, signed with the
signature block."""


def triage_email(email_text: str, app_ctx: dict, cv_text: str, signature: str) -> EmailTriage:
    prompt = (
        f"Application context: position '{app_ctx['title']}' at {app_ctx['company']} ({app_ctx['country']}).\n\n"
        f"EMAIL:\n{email_text[:10000]}\n\nCV TEXT:\n{cv_text[:8000]}\n\nSIGNATURE:\n{signature}"
    )
    try:
        if not store.get("ai_api_key"):
            from .local_ai import LocalIntelligentEngine
            return LocalIntelligentEngine.triage_email(email_text, app_ctx, cv_text, signature)
        return _generate(prompt, _TRIAGE_SYSTEM, EmailTriage)  # type: ignore[return-value]
    except Exception as exc:
        log.warning("Gemini triage_email error (%s), fallback to LocalIntelligentEngine", exc)
        from .local_ai import LocalIntelligentEngine
        return LocalIntelligentEngine.triage_email(email_text, app_ctx, cv_text, signature)


def research_company(company: str, country: str) -> str:
    try:
        return _generate(
            f"Give a factual briefing (max 180 words) about the company '{company}' in {country}: activity, size, "
            "main clients or projects, recent news, and values. If unsure, say so.",
            "You are a precise business researcher. Use search results; do not speculate.",
            search=True,
        )  # type: ignore[return-value]
    except Exception as exc:
        log.warning("Company research failed: %s", exc)
        return ""


_PREP_SYSTEM = """You are an interview coach. Prepare the candidate for the interview described.
Suggested answers must rely ONLY on facts present in the CV text; never invent experience.
Produce exactly 10 likely questions with suggested answers, in the language of the interview email."""


def interview_prep(job: dict, email_text: str, cv_text: str, company_brief: str) -> InterviewPrep:
    if store.get("ai_api_key"):
        try:
            prompt = (
                f"Position: {job['title']} at {job['company']} ({job['country']})\nPosting:\n{job['description'][:6000]}\n\n"
                f"Company briefing (from web research):\n{company_brief or 'not available'}\n\n"
                f"Invitation email:\n{email_text[:5000]}\n\nCV TEXT:\n{cv_text[:12000]}"
            )
            return _generate(prompt, _PREP_SYSTEM, InterviewPrep, temperature=0.3)  # type: ignore[return-value]
        except Exception as exc:
            log.warning("Remote interview_prep failed (%s), fallback to LocalIntelligentEngine", exc)
    from .local_ai import LocalIntelligentEngine
    return LocalIntelligentEngine.interview_prep(job, email_text, cv_text, company_brief)


def extract_cv_profile(cv_text: str) -> CvProfile:
    if store.get("ai_api_key"):
        try:
            return _generate(
                f"CV TEXT:\n{cv_text[:15000]}",
                "Extract a structured profile from this CV. Use only what is written. Do not infer missing data; "
                "use empty strings when absent.",
                CvProfile,
            )  # type: ignore[return-value]
        except Exception as exc:
            log.warning("Remote extract_cv_profile failed (%s), fallback to LocalIntelligentEngine", exc)
    from .local_ai import LocalIntelligentEngine
    return LocalIntelligentEngine.extract_cv_profile(cv_text)


def dumps(obj: BaseModel) -> str:
    return json.dumps(obj.model_dump(mode="json"), ensure_ascii=False)
