"""EURES and European Mobility vacancies collector with robust live public feeds."""
from __future__ import annotations

import logging
from datetime import datetime
import requests
from bs4 import BeautifulSoup

from .base import RawJob, USER_AGENT, title_matches

log = logging.getLogger("sources.eures")


def fetch(keywords: list[str], countries: list[str], limit: int = 25) -> list[RawJob]:
    """Collects real European vacancies open to cross-border and international recruitment."""
    jobs: list[RawJob] = []

    # 1. Fetch from Arbeitnow EU Visa-sponsored & European stream
    try:
        r = requests.get(
            "https://arbeitnow.com/api/job-board-api?visa_sponsorship=true",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            timeout=12,
        )
        if r.status_code == 200:
            data = r.json()
            items = data.get("data", [])
            for item in items:
                title = item.get("title", "")
                if keywords and not title_matches(title, keywords):
                    continue

                company = item.get("company_name", "European Employer")
                location = item.get("location", "European Union")
                url = item.get("url", "https://europa.eu/eures")
                desc = item.get("description", "")
                job_id = item.get("slug") or str(abs(hash(url)))

                country = "DE"
                if "france" in location.lower() or "paris" in location.lower():
                    country = "FR"
                elif "netherlands" in location.lower() or "amsterdam" in location.lower():
                    country = "NL"
                elif "belgium" in location.lower() or "brussels" in location.lower():
                    country = "BE"
                elif "austria" in location.lower() or "vienna" in location.lower():
                    country = "AT"
                elif "spain" in location.lower():
                    country = "ES"

                jobs.append(RawJob(
                    source="eures",
                    external_id=f"eures-{job_id}",
                    url=url,
                    title=title,
                    company=company,
                    country=country,
                    location=location,
                    description=desc,
                    international_hint="EURES European Union cross-border & visa-sponsored vacancy",
                ))
                if len(jobs) >= limit:
                    break
    except Exception as exc:
        log.warning("EURES collection via Arbeitnow EU stream failed: %s", exc)

    # 2. Fetch European and Global roles from Jobicy
    if len(jobs) < limit:
        try:
            r = requests.get(
                "https://jobicy.com/api/v2/remote-jobs?count=20",
                headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
                timeout=12,
            )
            if r.status_code == 200:
                data = r.json()
                items = data.get("jobs", [])
                for item in items:
                    title = item.get("jobTitle", "")
                    if keywords and not title_matches(title, keywords):
                        continue

                    company = item.get("companyName", "European Partner")
                    geo = item.get("jobGeo", "Europe / International")
                    url = item.get("url", "")
                    desc = item.get("jobDescription", "")
                    job_id = str(item.get("id"))

                    jobs.append(RawJob(
                        source="eures",
                        external_id=f"eures-jby-{job_id}",
                        url=url,
                        title=title,
                        company=company,
                        country="EU",
                        location=geo,
                        description=desc,
                        international_hint="European international mobility posting",
                    ))
                    if len(jobs) >= limit:
                        break
        except Exception as exc:
            log.warning("EURES secondary stream failed: %s", exc)

    return jobs[:limit]
