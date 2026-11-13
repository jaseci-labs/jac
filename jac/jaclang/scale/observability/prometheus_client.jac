import os;
import math;
import logging;

glob logger = logging.getLogger(__name__),
     _warned_once: set = set();


def _warn_once(key: str, msg: str);

def resolve_prometheus_url -> str | None;

def query(promql: str, timeout: float = 3.0) -> list[dict[str, any]] | None;

def _extract_result(body: any) -> list[dict[str, any]];

def query_range(
    promql: str, start: float, end: float, step: str = "15s", timeout: float = 5.0
) -> list[dict[str, any]] | None;

def scalar(result: any, fallback: float = 0.0) -> float;
