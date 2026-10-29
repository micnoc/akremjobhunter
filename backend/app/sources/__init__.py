from . import adzuna, arbeitnow, careerjet, company_pages, eures, jobbank, jobspy_src, jooble, remote_portals
from .base import RawJob
from .sources_tracker import SourcesTracker

REGISTRY = {
    "jobbank": jobbank.fetch,
    "eures": eures.fetch,
    "careerjet": careerjet.fetch,
    "jooble": jooble.fetch,
    "company_careers": company_pages.fetch,
    "arbeitnow": arbeitnow.fetch,
    "remote_portals": remote_portals.fetch,
    "adzuna": adzuna.fetch,
    "jobspy": jobspy_src.fetch,
}

__all__ = ["REGISTRY", "RawJob", "SourcesTracker"]
