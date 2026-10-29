"""Live telemetry tracker for all integrated job discovery sources."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from .base import RawJob
from ..models import utcnow


class SourcesTracker:
    _sources_state: dict[str, dict[str, Any]] = {
        "jobbank": {
            "name": "Job Bank Canada",
            "region": "Canada (LMIA / fglo=1)",
            "status": "ONLINE",
            "health": "EXCELLENT",
            "last_scan": None,
            "jobs_found": 0,
            "target_countries": ["CA"],
        },
        "eures": {
            "name": "EURES European Employment",
            "region": "European Union (Mobility)",
            "status": "ONLINE",
            "health": "EXCELLENT",
            "last_scan": None,
            "jobs_found": 0,
            "target_countries": ["DE", "FR", "BE", "NL", "AT", "IE"],
        },
        "careerjet": {
            "name": "CareerJet Global",
            "region": "UK, Canada, Europe, GCC",
            "status": "ONLINE",
            "health": "EXCELLENT",
            "last_scan": None,
            "jobs_found": 0,
            "target_countries": ["GB", "CA", "FR", "DE", "AE"],
        },
        "jooble": {
            "name": "Jooble International",
            "region": "International Job Boards",
            "status": "ONLINE",
            "health": "EXCELLENT",
            "last_scan": None,
            "jobs_found": 0,
            "target_countries": ["CA", "FR", "DE", "GB"],
        },
        "company_careers": {
            "name": "Company Career Portals",
            "region": "Direct Multinational Employers",
            "status": "ONLINE",
            "health": "EXCELLENT",
            "last_scan": None,
            "jobs_found": 0,
            "target_countries": ["GLOBAL"],
        },
    }

    @classmethod
    def record_scan(cls, source_name: str, count: int, error: str | None = None) -> None:
        state = cls._sources_state.get(source_name)
        if not state:
            state = {
                "name": source_name.title(),
                "region": "International",
                "status": "ONLINE",
                "health": "GOOD",
                "last_scan": None,
                "jobs_found": 0,
            }
            cls._sources_state[source_name] = state

        state["last_scan"] = utcnow().isoformat()
        if error:
            state["status"] = "WARNING"
            state["health"] = "DEGRADED"
            state["error"] = error
        else:
            state["status"] = "ONLINE"
            state["health"] = "EXCELLENT"
            state["jobs_found"] += count

    @classmethod
    def get_all_status(cls) -> list[dict[str, Any]]:
        result = []
        for src_id, info in cls._sources_state.items():
            result.append({
                "id": src_id,
                **info,
            })
        return result
