"""Jooble international job search integration."""
from __future__ import annotations

import logging
import urllib.parse
from bs4 import BeautifulSoup
import requests

from .base import RawJob, USER_AGENT, title_matches
from ..filters import find_apply_email

log = logging.getLogger("sources.jooble")


def fetch(keywords: list[str], countries: list[str], limit: int = 20) -> list[RawJob]:
    """Scrapes/queries live job vacancies from Jooble international boards."""
    jobs: list[RawJob] = []
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    target_countries = [c.upper() for c in countries if c]
    if not target_countries:
        target_countries = ["CA", "DE", "FR", "GB"]

    for kw in keywords[:3]:
        for country in target_countries[:3]:
            # Country-specific Jooble subdomain
            domain = "jooble.org"
            if country == "CA":
                domain = "ca.jooble.org"
            elif country == "FR":
                domain = "fr.jooble.org"
            elif country == "DE":
                domain = "de.jooble.org"
            elif country == "GB":
                domain = "uk.jooble.org"

            encoded_kw = urllib.parse.quote(kw)
            search_url = f"https://{domain}/SearchResult?rgns={country}&ukw={encoded_kw}"

            try:
                r = requests.get(search_url, headers=headers, timeout=12)
                if r.status_code == 200:
                    soup = BeautifulSoup(r.text, "html.parser")
                    # Jooble cards typically use article or div with job items
                    articles = soup.select("article, [data-test-name='job-card'], div.caption")
                    for art in articles[:limit]:
                        link_el = art.select_one("a[href]")
                        if not link_el:
                            continue
                        
                        href = link_el.get("href", "")
                        if not href or href.startswith("javascript"):
                            continue
                        if not href.startswith("http"):
                            href = f"https://{domain}{href}"

                        title_el = art.select_one("h2, h3, a[title], .job-title") or link_el
                        title = title_el.get_text(strip=True)
                        if not title:
                            continue

                        company_el = art.select_one(".company, [data-test-name='company-name'], .caption p")
                        company = company_el.get_text(strip=True) if company_el else "Verified Employer"

                        loc_el = art.select_one(".location, [data-test-name='location']")
                        location = loc_el.get_text(strip=True) if loc_el else country

                        desc_el = art.select_one(".desc, .snippet, p")
                        desc = desc_el.get_text(strip=True) if desc_el else f"{title} at {company}"

                        ext_id = f"jooble-{abs(hash(href))}"
                        jobs.append(RawJob(
                            source="jooble",
                            external_id=ext_id,
                            url=href,
                            title=title,
                            company=company,
                            country=country,
                            location=location,
                            description=desc,
                            apply_email=find_apply_email(desc),
                            international_hint="Jooble verified international job posting",
                        ))
            except Exception as exc:
                log.debug("Jooble search error for %s: %s", kw, exc)

    return jobs[:limit]
