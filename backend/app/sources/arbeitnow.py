"""Arbeitnow public API (Germany / EU), filtered to postings flagged with visa sponsorship."""
from __future__ import annotations

import logging
from datetime import datetime, timezone

import requests
from bs4 import BeautifulSoup

from ..filters import find_apply_email
from .base import USER_AGENT, RawJob, title_matches

log = logging.getLogger("src.arbeitnow")
HINT = "Arbeitnow: posting explicitly flagged by the employer as offering visa sponsorship."


def fetch(keywords: list[str], countries: list[str], pages: int = 4) -> list[RawJob]:
    if "DE" not in countries:
        return []
    out: list[RawJob] = []
    for page in range(1, pages + 1):
        try:
            r = requests.get(
                "https://www.arbeitnow.com/api/job-board-api",
                params={"visa_sponsorship": "true", "page": page},
                headers={"User-Agent": USER_AGENT}, timeout=40,
            )
            r.raise_for_status()
            data = r.json().get("data", [])
        except Exception as exc:
            log.warning("page %s failed: %s", page, exc)
            break
        if not data:
            break
        for j in data:
            if not j.get("visa_sponsorship"):
                continue
            if not title_matches(j.get("title", ""), keywords):
                continue
            desc = BeautifulSoup(j.get("description") or "", "html.parser").get_text("\n", strip=True)
            created = j.get("created_at")
            out.append(RawJob(
                source="arbeitnow", external_id=j["slug"], url=j.get("url", ""), title=j.get("title", ""),
                company=j.get("company_name", ""), country="DE", location=j.get("location", ""),
                description=desc[:15000], apply_email=find_apply_email(desc),
                posted_at=datetime.fromtimestamp(created, tz=timezone.utc) if isinstance(created, (int, float)) else None,
                international_hint=HINT,
            ))
    return out
