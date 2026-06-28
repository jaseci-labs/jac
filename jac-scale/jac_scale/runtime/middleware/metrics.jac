def build_gateway_metrics(
    namespace: str = "jac_scale", histogram_buckets: list[float] | None = None
) -> tuple[any, any, any] {
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

def render_metrics(registry: any) -> tuple[bytes, str] {
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
