"""Adzuna official API (EU, UK, Canada, USA). Requires a free app_id / app_key."""
from __future__ import annotations

import logging
import random
from datetime import datetime

import requests

from .. import settings_store as store
from ..filters import find_apply_email
from .base import RawJob

log = logging.getLogger("src.adzuna")
SUPPORTED = {"AT", "BE", "CA", "CH", "DE", "ES", "FR", "GB", "IT", "NL", "PL", "US"}


def fetch(keywords: list[str], countries: list[str], max_calls: int = 12) -> list[RawJob]:
    app_id, app_key = store.get("adzuna_app_id"), store.get("adzuna_app_key")
    if not app_id or not app_key:
        return []
    combos = [(c, k) for c in countries if c in SUPPORTED for k in keywords]
    random.shuffle(combos)
    out: list[RawJob] = []
    for country, kw in combos[:max_calls]:
        try:
            r = requests.get(
                f"https://api.adzuna.com/v1/api/jobs/{country.lower()}/search/1",
                params={"app_id": app_id, "app_key": app_key, "what": kw, "results_per_page": 20,
                        "max_days_old": 10, "sort_by": "date", "content-type": "application/json"},
                timeout=40,
            )
            r.raise_for_status()
        except Exception as exc:
            log.warning("%s/%s failed: %s", country, kw, exc)
            continue
        for j in r.json().get("results", []):
            desc = j.get("description", "")
            try:
                posted = datetime.fromisoformat(j["created"].replace("Z", "+00:00")) if j.get("created") else None
            except ValueError:
                posted = None
            out.append(RawJob(
                source="adzuna", external_id=str(j.get("id")), url=j.get("redirect_url", ""),
                title=j.get("title", ""), company=(j.get("company") or {}).get("display_name", ""),
                country=country, location=(j.get("location") or {}).get("display_name", ""),
                description=desc, apply_email=find_apply_email(desc), posted_at=posted,
            ))
    return out


def test() -> str:
    res = fetch(["driver"], ["GB"], max_calls=1)
    return f"Adzuna OK ({len(res)} results for a probe query)"
