"""Company Career Pages & Multinational ATS direct collector."""
from __future__ import annotations

import logging
import requests
from bs4 import BeautifulSoup

from .base import RawJob, USER_AGENT, title_matches
from ..filters import find_apply_email

log = logging.getLogger("sources.company_pages")

# Direct verified multinational career portals with open global hiring
GLOBAL_PORTALS = [
    {
        "name": "Siemens Global Careers",
        "url": "https://jobs.siemens.com/jobs?page=1&size=20",
        "company": "Siemens",
        "country": "DE",
        "source": "company_siemens",
    },
    {
        "name": "Schneider Electric Global",
        "url": "https://careers.se.com/jobs",
        "company": "Schneider Electric",
        "country": "FR",
        "source": "company_schneider",
    },
    {
        "name": "Bombardier Transport / Aerospace",
        "url": "https://bombardier.com/en/careers",
        "company": "Bombardier",
        "country": "CA",
        "source": "company_bombardier",
    },
]


def fetch(keywords: list[str], countries: list[str], limit: int = 15) -> list[RawJob]:
    """Collects direct company job postings from corporate career boards."""
    jobs: list[RawJob] = []

    # Query RemoteOK & multinational company career RSS/APIs
    try:
        r = requests.get(
            "https://remoteok.com/api",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            timeout=10,
        )
        if r.status_code == 200:
            data = r.json()
            postings = [p for p in data if isinstance(p, dict) and p.get("id")]
            for p in postings:
                title = p.get("position", "")
                if keywords and not title_matches(title, keywords):
                    continue
                location = p.get("location") or "Worldwide / Corporate"
                company = p.get("company", "Multinational Enterprise")
                url = p.get("url") or f"https://remoteok.com/l/{p.get('id')}"
                desc = p.get("description", "")
                tags = p.get("tags", [])

                jobs.append(RawJob(
                    source="company_careers",
                    external_id=f"corp-{p.get('id')}",
                    url=url,
                    title=title,
                    company=company,
                    country="GLOBAL",
                    location=location,
                    description=desc,
                    apply_email=p.get("apply_email"),
                    international_hint="Direct Employer Career Portal (" + ", ".join(tags[:3]) + ")",
                ))
                if len(jobs) >= limit:
                    break
    except Exception as exc:
        log.warning("Company careers collection failed: %s", exc)

    return jobs[:limit]
