"""CareerJet live job search integration."""
from __future__ import annotations

import logging
import urllib.parse
import xml.etree.ElementTree as ET
import requests

from .base import RawJob, USER_AGENT, title_matches
from ..filters import find_apply_email

log = logging.getLogger("sources.careerjet")

# Public search endpoint for CareerJet
LOCALE_MAP = {
    "GB": "en_GB",
    "CA": "en_CA",
    "FR": "fr_FR",
    "DE": "de_DE",
    "US": "en_US",
    "AE": "en_AE",
    "QA": "en_QA",
    "SA": "en_SA",
}


def fetch(keywords: list[str], countries: list[str], limit: int = 20) -> list[RawJob]:
    """Scrapes/queries live job vacancies from CareerJet."""
    jobs: list[RawJob] = []
    
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/xml, application/xml, text/html, */*",
    }

    target_countries = [c.upper() for c in countries if c.upper() in LOCALE_MAP]
    if not target_countries:
        target_countries = ["CA", "GB", "DE", "FR"]

    for kw in keywords[:3]:
        for country in target_countries[:3]:
            locale = LOCALE_MAP.get(country, "en_GB")
            encoded_kw = urllib.parse.quote(kw)
            rss_url = f"https://www.careerjet.co.uk/search/rss?s={encoded_kw}&l={country}&sort=date"
            if country == "CA":
                rss_url = f"https://www.careerjet.ca/search/rss?s={encoded_kw}&sort=date"
            elif country == "FR":
                rss_url = f"https://www.optioncarriere.com/emploi/rss?s={encoded_kw}&sort=date"
            elif country == "DE":
                rss_url = f"https://www.careerjet.de/suche/rss?s={encoded_kw}&sort=date"

            try:
                r = requests.get(rss_url, headers=headers, timeout=12)
                if r.status_code == 200 and ("<item>" in r.text or "<entry>" in r.text):
                    root = ET.fromstring(r.content)
                    channel = root.find("channel")
                    items = channel.findall("item") if channel is not None else root.findall(".//item")
                    
                    for item in items[:limit]:
                        title = item.findtext("title", "").strip()
                        link = item.findtext("link", "").strip()
                        desc = item.findtext("description", "").strip()
                        guid = item.findtext("guid", link).strip()
                        
                        if not title or not link:
                            continue
                        
                        # Extract company if available in title or description
                        company = "CareerJet Partner"
                        if " at " in title:
                            parts = title.split(" at ")
                            title = parts[0].strip()
                            company = parts[1].strip()
                        elif " - " in title:
                            parts = title.split(" - ")
                            title = parts[0].strip()
                            company = parts[1].strip()

                        ext_id = f"cj-{abs(hash(guid or link))}"
                        jobs.append(RawJob(
                            source="careerjet",
                            external_id=ext_id,
                            url=link,
                            title=title,
                            company=company,
                            country=country,
                            location=f"{country}",
                            description=desc,
                            apply_email=find_apply_email(desc),
                            international_hint="CareerJet direct indexed vacancy",
                        ))
            except Exception as exc:
                log.debug("CareerJet RSS error for %s in %s: %s", kw, country, exc)

    return jobs[:limit]
