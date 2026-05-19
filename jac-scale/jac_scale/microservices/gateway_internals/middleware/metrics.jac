"""Prometheus metrics for the microservice gateway.

Gateway-level metrics are collected in a dedicated registry (not the
default one) so spawning multiple gateways in-process during tests
doesn't get "duplicated timeseries in CollectorRegistry" errors.

Metrics exposed at `/metrics` on the gateway:

  jac_scale_gateway_requests_total{service, method, outcome}  Counter
  jac_scale_gateway_request_duration_seconds{service, method}  Histogram

The `service` label is the microservice name matched by prefix routing,
or one of these special values:
  "__builtin__"  -> /user, /walker, /function, /sso, etc. passthrough
  "__health__"   -> /health
  "__admin__"    -> /admin/*
  "__static__"   -> SPA or static files
  "__unmatched__"-> 404 (no route)

`outcome` is "2xx" / "3xx" / "4xx" / "5xx" / "err" (connection/proxy
failure with no HTTP response).

K8s parallel: Prometheus scrapes http://{gateway-pod}:8000/metrics.
Local: curl http://localhost:8000/metrics. Same exposition, same
metric names, so dashboards written for local work in K8s unchanged.
"""

import from typing { Any }

# Factories return None when prometheus_client isn't installed. Callers
# no-op in that case (gateway still works, metrics just aren't emitted).
"""Build the gateway's Counter + Histogram on a fresh CollectorRegistry.

Returns (registry, requests_counter, duration_histogram) or (None, None, None)
if prometheus_client isn't available.
"""
def build_gateway_metrics(
    namespace: str = "jac_scale", histogram_buckets: list[float] | None = None
) -> tuple[Any, Any, Any] {
    try {
        import from prometheus_client { CollectorRegistry, Counter, Histogram }
    } except ImportError {
        return (None, None, None);
    }

    registry = CollectorRegistry();
    buckets = histogram_buckets
    or [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0];

    requests = Counter(
        "gateway_requests_total",
        "Total requests routed through the microservice gateway.",
        labelnames=["service", "method", "outcome"],
        namespace=namespace,
        registry=registry
    );
    duration = Histogram(
        "gateway_request_duration_seconds",
        "Wall-clock duration of gateway request handling.",
        labelnames=["service", "method"],
        namespace=namespace,
        buckets=buckets,
        registry=registry
    );

    return (registry, requests, duration);
}

"""Classify an HTTP status code into an 'outcome' label value."""
def classify_outcome(status_code: int) -> str {
    if status_code <= 0 {
        return "err";
    }
    if status_code < 300 {
        return "2xx";
    }
    if status_code < 400 {
        return "3xx";
    }
    if status_code < 500 {
        return "4xx";
    }
    return "5xx";
}

"""Render the Prometheus exposition text for a registry.

Returns (body: bytes, content_type: str). Returns (b"", "text/plain")
if prometheus_client isn't installed - caller should 503 in that case.
"""
def render_metrics(registry: Any) -> tuple[bytes, str] {
    if registry is None {
        return (b"", "text/plain");
    }
    try {
        import from prometheus_client { generate_latest, CONTENT_TYPE_LATEST }
    } except ImportError {
        return (b"", "text/plain");
    }
    return (generate_latest(registry), CONTENT_TYPE_LATEST);
}
