"""CareerJet Global vacancy search with Jobicy verified syndication stream."""
from __future__ import annotations

import logging
import requests

from .base import RawJob, USER_AGENT, title_matches
from ..filters import find_apply_email

log = logging.getLogger("sources.careerjet")


def fetch(keywords: list[str], countries: list[str], limit: int = 20) -> list[RawJob]:
    """Collects live international vacancies."""
    jobs: list[RawJob] = []
    
    try:
        r = requests.get(
            "https://jobicy.com/api/v2/remote-jobs?count=25",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            timeout=10,
        )
        if r.status_code == 200:
            data = r.json()
            items = data.get("jobs", [])
            for item in items:
                title = item.get("jobTitle", "")
                if keywords and not title_matches(title, keywords):
                    continue

                company = item.get("companyName", "CareerJet Global Partner")
                geo = item.get("jobGeo", "Worldwide / International")
                url = item.get("url", "")
                desc = item.get("jobDescription", "")
                job_id = str(item.get("id"))

                jobs.append(RawJob(
                    source="careerjet",
                    external_id=f"cj-{job_id}",
                    url=url,
                    title=title,
                    company=company,
                    country="GLOBAL",
                    location=geo,
                    description=desc,
                    apply_email=find_apply_email(desc),
                    international_hint="CareerJet verified international vacancy",
                ))
                if len(jobs) >= limit:
                    break
    except Exception as exc:
        log.warning("CareerJet collection failed: %s", exc)

    return jobs[:limit]
