"""LinkedIn / Indeed / Glassdoor / Google Jobs public listings via python-jobspy.

Reads public search pages WITHOUT logging in to any account, so personal accounts are never at risk.
Volume is deliberately small per run.
"""
from __future__ import annotations

import logging
import math
import random

from ..filters import find_apply_email
from .base import COUNTRY_NAMES, RawJob

log = logging.getLogger("src.jobspy")


def fetch(keywords: list[str], countries: list[str], max_combos: int = 5) -> list[RawJob]:
    try:
        from jobspy import scrape_jobs
    except ImportError:
        log.warning("python-jobspy not installed")
        return []
    combos = [(c, k) for c in countries if c in COUNTRY_NAMES for k in keywords]
    random.shuffle(combos)
    out: list[RawJob] = []
    for country, kw in combos[:max_combos]:
        cname = COUNTRY_NAMES[country]
        try:
            df = scrape_jobs(
                site_name=["indeed", "linkedin", "glassdoor"],
                search_term=f"{kw} visa sponsorship" if country in ("US", "GB", "CA") else kw,
                location=cname.title() if cname not in ("uk", "usa") else cname.upper(),
                country_indeed=cname,
                results_wanted=12,
                hours_old=96,
                linkedin_fetch_description=True,
                description_format="markdown",
                verbose=0,
            )
        except Exception as exc:
            log.warning("%s/%s failed: %s", country, kw, exc)
            continue
        for row in df.to_dict("records"):
            desc = _s(row.get("description"))
            emails = row.get("emails")
            email = None
            if isinstance(emails, list) and emails:
                email = emails[0]
            elif isinstance(emails, str) and "@" in emails:
                email = emails.split(",")[0].strip()
            out.append(RawJob(
                source=f"jobspy:{_s(row.get('site')) or 'web'}",
                external_id=_s(row.get("id")) or _s(row.get("job_url")),
                url=_s(row.get("job_url_direct")) or _s(row.get("job_url")),
                title=_s(row.get("title")), company=_s(row.get("company")), country=country,
                location=_s(row.get("location")), description=desc[:15000],
                apply_email=email or find_apply_email(desc),
            ))
    return out


def _s(v) -> str:
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return ""
    return str(v)
