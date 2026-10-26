from . import adzuna, arbeitnow, jobbank, jobspy_src
from .base import RawJob

REGISTRY = {
    "jobbank": jobbank.fetch,
    "arbeitnow": arbeitnow.fetch,
    "adzuna": adzuna.fetch,
    "jobspy": jobspy_src.fetch,
}

__all__ = ["REGISTRY", "RawJob"]
