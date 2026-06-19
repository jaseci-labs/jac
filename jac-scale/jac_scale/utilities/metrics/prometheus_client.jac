"""Lightweight HTTP client for querying the in-cluster Prometheus instance.

Constructs the Prometheus service URL from the K8S_APP_NAME / K8S_NAMESPACE
env vars injected by jac-scale at deploy time and exposes thin wrappers over
Prometheus' /api/v1/query and /api/v1/query_range endpoints.

Returns parsed result lists (or None on failure) so callers don't have to deal
with the Prometheus response envelope or HTTP error handling.
"""
import os;
import math;
import logging;
import requests;
import from requests.exceptions { RequestException }

glob logger = logging.getLogger(__name__);

"""Resolve the in-cluster Prometheus base URL.

Honors PROMETHEUS_URL when set so deployments running outside the standard
monitoring stack (or local dev with port-forward) can point elsewhere.
"""
def resolve_prometheus_url -> str | None {
    override_url: str | None = os.environ.get("PROMETHEUS_URL");
    if override_url {
        return override_url.rstrip("/");
    }
    app_name: str | None = os.environ.get("K8S_APP_NAME");
    if not app_name {
        return None;
    }
    return f"http://{app_name}-prometheus-service:9090";
}

"""Run an instant PromQL query.

Returns the parsed `data.result` list, or None if Prometheus is unreachable
or returns a non-success status. Logs the failure so callers can show a
'metrics unavailable' state without surfacing the underlying error to users.
"""
def query(promql: str, timeout: float = 3.0) -> list[any] | None {
    base = resolve_prometheus_url();
    if not base {
        return None;
    }
    try {
        resp = requests.get(
            f"{base}/api/v1/query", params={"query": promql}, timeout=timeout
        );
        if resp.status_code != 200 {
            logger.warning(f"Prometheus query returned {resp.status_code}: {promql}");
            return None;
        }
        body = resp.json();
        if body.get("status") != "success" {
            logger.warning(f"Prometheus query failed: {body}");
            return None;
        }
        return _extract_result(body);
    } except RequestException as e {
        logger.warning(f"Prometheus unreachable: {e}");
        return None;
    } except Exception as e {
        logger.warning(f"Prometheus query error: {e}");
        return None;
    }
}

"""Pull `data.result` from a parsed Prometheus response JSON."""
def _extract_result(body: any) -> list[any] {
    try {
        data = body["data"];
        raw = data["result"];
        out: list[any] = [];
        if raw {
            for entry in raw {
                out.append(entry);
            }
        }
        return out;
    } except Exception {
        return [];
    }
}

"""Run a PromQL range query for time-series charts.

`start` and `end` are unix timestamps (seconds), `step` is the resolution
(e.g. '15s', '1m'). Returns the parsed `data.result` list or None on failure.
"""
def query_range(
    promql: str, start: float, end: float, step: str = "15s", timeout: float = 5.0
) -> list[any] | None {
    base = resolve_prometheus_url();
    if not base {
        return None;
    }
    try {
        resp = requests.get(
            f"{base}/api/v1/query_range",
            params={"query": promql, "start": start, "end": end, "step": step},
            timeout=timeout
        );
        if resp.status_code != 200 {
            logger.warning(
                f"Prometheus query_range returned {resp.status_code}: {promql}"
            );
            return None;
        }
        body = resp.json();
        if body.get("status") != "success" {
            logger.warning(f"Prometheus query_range failed: {body}");
            return None;
        }
        return _extract_result(body);
    } except RequestException as e {
        logger.warning(f"Prometheus unreachable: {e}");
        return None;
    } except Exception as e {
        logger.warning(f"Prometheus query_range error: {e}");
        return None;
    }
}

"""Extract the scalar numeric value from a single-vector Prometheus result.

Prometheus returns values as ['<timestamp>', '<value as string>']. This helper
parses the string into a float, returning the supplied fallback on missing
data or parse failures. Non-finite values (NaN/+Inf/-Inf) also fall back:
Prometheus emits "NaN" for empty histogram_quantile and "+Inf" for cAdvisor
buckets, and those are not JSON-serialisable.
"""
def scalar(result: any, fallback: float = 0.0) -> float {
    if not result {
        return fallback;
    }
    try {
        first = result[0];
        value = first["value"];
        parsed = float(str(value[1]));
        return parsed if math.isfinite(parsed) else fallback;
    } except Exception {
        return fallback;
    }
}
