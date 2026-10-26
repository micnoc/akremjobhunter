"""Job Bank Canada, restricted to postings open to international candidates (fglo=1)."""
from __future__ import annotations

import logging
import re
import time
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from ..filters import find_apply_email
from .base import USER_AGENT, RawJob

log = logging.getLogger("src.jobbank")
BASE = "https://www.jobbank.gc.ca"
HINT = "Job Bank Canada: posting listed under 'Canadians and international candidates' (employer accepts applicants from outside Canada)."


def fetch(keywords: list[str], countries: list[str], per_keyword: int = 12) -> list[RawJob]:
    if "CA" not in countries:
        return []
    out: list[RawJob] = []
    s = requests.Session()
    s.headers.update({"User-Agent": USER_AGENT, "Accept-Language": "en-CA,en;q=0.9"})
    for kw in keywords:
        try:
            r = s.get(f"{BASE}/jobsearch/jobsearch", params={"searchstring": kw, "fglo": 1, "sort": "D"}, timeout=40)
            r.raise_for_status()
        except Exception as exc:
            log.warning("search failed for %s: %s", kw, exc)
            continue
        soup = BeautifulSoup(r.text, "html.parser")
        for art in soup.select("article")[:per_keyword]:
            a = art.select_one("a.resultJobItem")
            if not a or not a.get("href"):
                continue
            m = re.search(r"/jobposting/(\d+)", a["href"])
            if not m:
                continue
            job_id = m.group(1)
            title = (art.select_one(".noctitle").get_text(" ", strip=True) if art.select_one(".noctitle") else "").strip()
            company = art.select_one(".business").get_text(" ", strip=True) if art.select_one(".business") else ""
            location = art.select_one(".location").get_text(" ", strip=True).replace("Location", "").strip() if art.select_one(".location") else ""
            date_txt = art.select_one(".date").get_text(" ", strip=True) if art.select_one(".date") else ""
            url = f"{BASE}/jobsearch/jobposting/{job_id}"
            desc = _detail(s, url)
            time.sleep(1.5)
            try:
                posted = datetime.strptime(date_txt, "%B %d, %Y") if date_txt else None
            except ValueError:
                posted = None
            out.append(RawJob(
                source="jobbank", external_id=job_id, url=url, title=title, company=company, country="CA",
                location=location, description=desc, apply_email=find_apply_email(desc), posted_at=posted,
                international_hint=HINT,
            ))
        time.sleep(2)
    return out


def _detail(s: requests.Session, url: str) -> str:
    try:
        r = s.get(url, timeout=40)
        r.raise_for_status()
    except Exception:
        return ""
    soup = BeautifulSoup(r.text, "html.parser")
    node = soup.select_one(".job-posting-details-body") or soup.select_one("main") or soup
    for tag in node.select("script, style, nav, footer"):
        tag.decompose()
    return re.sub(r"\n{3,}", "\n\n", node.get_text("\n", strip=True))[:15000]
