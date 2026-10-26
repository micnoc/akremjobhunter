"""Cheap rule-based pre-screening applied before any AI call."""
from __future__ import annotations

import re

_CITIZENSHIP = [
    r"\bmust be (a|an) (u\.?s\.?|canadian|eu|european|british|swiss) (citizen|national)",
    r"\b(u\.?s\.?|us) citizenship (is )?required",
    r"\bcitizens? only\b",
    r"\bsecurity clearance\b",
    r"\b(ts|top secret)/sci\b",
    r"\bno (visa )?sponsorship\b",
    r"\b(will not|cannot|unable to|do not) (provide |offer )?sponsor",
    r"\bwithout (the need for )?(visa )?sponsorship\b",
    r"\bmust (already )?(be|have) (legally )?(authori[sz]ed|eligible|entitled) to work in\b",
    r"\bvalid (eu |uk |canadian )?work permit (is )?required\b",
    r"\bpermanent residen(t|cy) (or citizen )?(status )?required\b",
    r"\bnationalit[ée] (française|belge|suisse) (exigée|requise|obligatoire)",
    r"\bressortissant (de l'ue|européen) (exigé|uniquement)",
    r"\bautorisation de travail (valide )?(exigée|obligatoire|requise)",
    r"\bkein(e)? (visum|visa)[- ]?(sponsoring|unterstützung)",
    r"\b(deutsche )?staatsangehörigkeit (erforderlich|vorausgesetzt)",
    r"\barbeitserlaubnis (erforderlich|vorausgesetzt)\b",
]

_GOVERNMENT = [
    r"\bgovernment of (canada|alberta|ontario|quebec|british columbia)\b",
    r"\bpublic service commission\b",
    r"\busajobs\b",
    r"\bfederal (agency|government|department)\b",
    r"\bfonction publique\b",
    r"\bconcours (externe|interne|administratif)\b",
    r"\bministère\b",
    r"\bbundesamt\b",
    r"\böffentlicher dienst\b",
    r"\bbeamte(r|nverhältnis)?\b",
]

_CIT_RE = [re.compile(p, re.I) for p in _CITIZENSHIP]
_GOV_RE = [re.compile(p, re.I) for p in _GOVERNMENT]


def prescreen(title: str, company: str, description: str) -> tuple[str, str] | None:
    """Return (eligibility, evidence) if the job is clearly ineligible, else None."""
    text = f"{title}\n{company}\n{description}"
    for rx in _GOV_RE:
        m = rx.search(text)
        if m:
            return "GOVERNMENT_OR_CITIZENSHIP", _context(text, m)
    for rx in _CIT_RE:
        m = rx.search(text)
        if m:
            return "REQUIRES_WORK_PERMIT", _context(text, m)
    return None


def _context(text: str, m: re.Match) -> str:
    start, end = max(0, m.start() - 80), min(len(text), m.end() + 80)
    return " ".join(text[start:end].split())


EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_NOREPLY = re.compile(r"(no-?reply|donotreply|privacy|gdpr|support@|info@jobbank|webmaster)", re.I)


def find_apply_email(text: str) -> str | None:
    for e in EMAIL_RE.findall(text or ""):
        e = e.strip(".").lower()
        if not _NOREPLY.search(e) and not e.endswith((".png", ".jpg", ".gif")):
            return e
    return None
