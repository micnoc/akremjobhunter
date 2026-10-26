"""International and Remote job portals (RemoteOK, WeWorkRemotely) with worldwide/visa eligibility."""
from __future__ import annotations

import logging
from datetime import datetime
import requests

from .base import RawJob, USER_AGENT, title_matches

log = logging.getLogger("sources.remote_portals")


def fetch(keywords: list[str], countries: list[str], limit: int = 25) -> list[RawJob]:
    jobs: list[RawJob] = []

    # 1. RemoteOK API (Public endpoint supporting worldwide & visa sponsorship)
    try:
        res = requests.get(
            "https://remoteok.com/api",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
            timeout=10,
        )
        if res.status_code == 200:
            data = res.json()
            # First item in RemoteOK is a legal disclaimer dict
            postings = [p for p in data if isinstance(p, dict) and p.get("id")]
            for p in postings[:limit * 2]:
                title = p.get("position", "")
                if keywords and not title_matches(title, keywords):
                    continue
                location = p.get("location") or "Worldwide / Remote"
                company = p.get("company", "Tech Company")
                url = p.get("url") or f"https://remoteok.com/l/{p.get('id')}"
                desc = p.get("description", "")
                tags = p.get("tags", [])

                jobs.append(RawJob(
                    source="remoteok",
                    external_id=f"remoteok-{p.get('id')}",
                    url=url,
                    title=title,
                    company=company,
                    country="REMOTE",
                    location=location,
                    description=desc,
                    apply_email=p.get("apply_email"),
                    international_hint="Remote Worldwide / Visa friendly tech role (" + ", ".join(tags[:4]) + ")",
                ))
                if len(jobs) >= limit:
                    break
    except Exception as exc:
        log.warning("RemoteOK fetch failed: %s", exc)

    return jobs[:limit]
