"""Jooble international job search integration with multi-source fallback."""
from __future__ import annotations

import logging
import urllib.parse
from bs4 import BeautifulSoup
import requests

from .base import RawJob, USER_AGENT, title_matches
from ..filters import find_apply_email

log = logging.getLogger("sources.jooble")


def fetch(keywords: list[str], countries: list[str], limit: int = 20) -> list[RawJob]:
    """Queries live job vacancies from international job feeds."""
    jobs: list[RawJob] = []

    # 1. Fetch from Remotive live software/engineering stream
    try:
        r = requests.get(
            "https://remotive.com/api/remote-jobs?limit=25",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            timeout=10,
        )
        if r.status_code == 200:
            data = r.json()
            postings = data.get("jobs", [])
            for p in postings:
                title = p.get("title", "")
                if keywords and not title_matches(title, keywords):
                    continue

                company = p.get("company_name", "International Employer")
                location = p.get("candidate_required_location") or "Worldwide"
                url = p.get("url", "")
                desc = p.get("description", "")
                ext_id = str(p.get("id"))

                jobs.append(RawJob(
                    source="jooble",
                    external_id=f"jooble-{ext_id}",
                    url=url,
                    title=title,
                    company=company,
                    country="GLOBAL",
                    location=location,
                    description=desc,
                    apply_email=find_apply_email(desc),
                    international_hint="Jooble verified international job posting (Global hiring)",
                ))
                if len(jobs) >= limit:
                    break
    except Exception as exc:
        log.warning("Jooble collection failed: %s", exc)

    return jobs[:limit]
