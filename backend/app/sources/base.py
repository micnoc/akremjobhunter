"""Job sources. Each source returns RawJob items; failures are isolated per source."""
from __future__ import annotations

import hashlib
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)

COUNTRY_NAMES = {
    "DE": "germany", "FR": "france", "BE": "belgium", "NL": "netherlands", "LU": "luxembourg",
    "CH": "switzerland", "AT": "austria", "IT": "italy", "ES": "spain", "PT": "portugal",
    "IE": "ireland", "PL": "poland", "CZ": "czech republic", "SE": "sweden", "DK": "denmark",
    "NO": "norway", "FI": "finland", "GB": "uk", "CA": "canada", "US": "usa",
}


@dataclass
class RawJob:
    source: str
    external_id: str
    url: str
    title: str
    company: str
    country: str
    location: str
    description: str
    apply_email: str | None = None
    posted_at: datetime | None = None
    international_hint: str | None = None

    @property
    def fingerprint(self) -> str:
        key = f"{normalize(self.company)}|{normalize(self.title)}|{self.country.upper()}"
        return hashlib.sha256(key.encode()).hexdigest()


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text or "").encode("ascii", "ignore").decode().lower()
    text = re.sub(r"\b(m/w/d|w/m/d|h/f|f/h|m/f/d|gmbh|inc|ltd|llc|sarl|sas|bv|ag)\b", " ", text)
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def title_matches(title: str, keywords: list[str]) -> bool:
    t = normalize(title)
    for kw in keywords:
        tokens = [tok for tok in normalize(kw).split() if len(tok) > 2]
        if tokens and all(tok in t for tok in tokens):
            return True
    return False
