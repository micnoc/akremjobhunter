"""EURES (European Employment Services) collector for European vacancies."""
from __future__ import annotations

import logging
from datetime import datetime
import requests
from bs4 import BeautifulSoup

from .base import RawJob, USER_AGENT, title_matches

log = logging.getLogger("sources.eures")

EURES_API = "https://eures.ec.europa.eu/eures-services/jv-search/v1/search"
EURES_PORTAL = "https://eures.ec.europa.eu/portal/jv-se/search"


def fetch(keywords: list[str], countries: list[str], limit: int = 25) -> list[RawJob]:
    """Scrapes/queries European employment vacancies from EURES."""
    jobs: list[RawJob] = []
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json, text/plain, */*",
        "Content-Type": "application/json",
    }

    # Query per country
    target_countries = [c.upper() for c in countries if c.upper() in {"DE", "FR", "BE", "NL", "LU", "AT", "IT", "ES", "IE", "SE", "NO", "DK", "PL", "CZ", "CH"}]
    if not target_countries:
        target_countries = ["DE", "FR", "BE", "NL"]

    for kw in keywords[:3]:
        for country in target_countries[:4]:
            payload = {
                "keywords": [{"keyword": kw}],
                "countries": [country],
                "resultsPerPage": min(limit, 20),
                "page": 1,
                "sortSearch": "BEST_MATCH",
            }
            try:
                res = requests.post(EURES_API, json=payload, headers=headers, timeout=12)
                if res.status_code == 200:
                    data = res.json()
                    items = data.get("jvs", []) or data.get("results", []) or []
                    for item in items:
                        ext_id = str(item.get("id") or item.get("jobId") or item.get("reference") or "")
                        title = item.get("title") or item.get("jobTitle") or ""
                        company = item.get("employerName") or item.get("company") or "European Employer"
                        city = item.get("city") or item.get("location") or ""
                        desc = item.get("description") or item.get("jobDescription") or f"EURES Vacancy: {title} in {city}, {country}"
                        apply_url = item.get("url") or f"{EURES_PORTAL}?id={ext_id}"

                        if ext_id and title:
                            jobs.append(RawJob(
                                source="eures",
                                external_id=f"eures-{ext_id}",
                                url=apply_url,
                                title=title,
                                company=company,
                                country=country,
                                location=f"{city}, {country}".strip(", "),
                                description=desc,
                                international_hint="EURES EU mobility vacancy (open to cross-border EU recruitment)",
                            ))
            except Exception as exc:
                log.debug("EURES API attempt failed: %s", exc)

    # Fallback to public RSS/web if API returns empty
    if not jobs:
        try:
            for kw in keywords[:2]:
                url = f"https://eures.ec.europa.eu/portal/jv-se/search?keyword={kw}"
                r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
                if r.status_code == 200:
                    soup = BeautifulSoup(r.text, "html.parser")
                    for card in soup.select(".jv-item, .search-result-item, article")[:limit]:
                        link = card.select_one("a[href]")
                        t_el = card.select_one(".title, h2, h3")
                        if link and t_el:
                            t = t_el.get_text(strip=True)
                            href = link["href"]
                            c_name = "European Employer"
                            c_el = card.select_one(".employer, .company")
                            if c_el:
                                c_name = c_el.get_text(strip=True)
                            jobs.append(RawJob(
                                source="eures",
                                external_id=f"eures-{hash(href)}",
                                url=href if href.startswith("http") else f"https://eures.ec.europa.eu{href}",
                                title=t,
                                company=c_name,
                                country="EU",
                                location="European Union",
                                description=f"EURES posting: {t} at {c_name}",
                                international_hint="EURES European Union cross-border posting",
                            ))
        except Exception as exc:
            log.warning("EURES fallback error: %s", exc)

    return jobs[:limit]
