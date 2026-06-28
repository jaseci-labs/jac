import os;
import math;
import logging;
import requests;
import from requests.exceptions { RequestException }

glob logger = logging.getLogger(__name__);

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
