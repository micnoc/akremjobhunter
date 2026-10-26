from . import adzuna, arbeitnow, eures, jobbank, jobspy_src, remote_portals
from .base import RawJob

REGISTRY = {
    "jobbank": jobbank.fetch,
    "arbeitnow": arbeitnow.fetch,
    "adzuna": adzuna.fetch,
    "eures": eures.fetch,
    "remote_portals": remote_portals.fetch,
    "jobspy": jobspy_src.fetch,
}

__all__ = ["REGISTRY", "RawJob"]
