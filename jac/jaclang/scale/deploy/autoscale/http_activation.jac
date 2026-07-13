"""Typed request/config model for KEDA HTTP Add-on activation: describes an
InterceptorRoute (routing, cold-start, timeouts) and the external-push
ScaledObject metrics that scale the target from zero on HTTP traffic."""

"""A single path to match in an InterceptorRoute routing rule."""
obj HTTPPathMatch {
    has value: str;
}

"""A single header (and optional value) to match in an InterceptorRoute routing rule."""
obj HTTPHeaderMatch {
    has name: str,
        value: (str | None) = None;
}

"""One routing rule; hosts/paths/headers within a rule are AND-ed together,
while separate rules in a list are OR-ed."""
obj HTTPRoutingRule {
    has hosts: list[str] = [],
        paths: list[HTTPPathMatch] = [],
        headers: list[HTTPHeaderMatch] = [];
}

"""The Service fronting the scale target; exactly one of port or port_name must be set."""
obj HTTPServiceTarget {
    has service: str,
        port: (int | None) = None,
        port_name: (str | None) = None;
}

"""Scales on in-flight request concurrency at the interceptor."""
obj HTTPConcurrencyMetric {
    has target_value: int;
}

"""Scales on request rate over a sliding window, sampled at the given granularity."""
obj HTTPRequestRateMetric {
    has target_value: int,
        window: str = "1m",
        granularity: str = "1s";
}

"""A static response the interceptor returns while the target is cold-starting."""
obj HTTPStaticResponse {
    has status_code: int = 503,
        body: (str | None) = None,
        body_from_config_map: (dict[str, str] | None) = None,
        headers: dict[str, str] = {};
}

"""What to serve while the scale target wakes from zero replicas: a static
placeholder, a fallback service, or both."""
obj HTTPColdStartSpec {
    has placeholder: (HTTPStaticResponse | None) = None,
        fallback_service: (HTTPServiceTarget | None) = None;
}

"""Timeouts the interceptor applies while waiting for and proxying to the scale target."""
obj HTTPTimeoutSpec {
    has readiness: (str | None) = None,
        request: (str | None) = None,
        response_header: (str | None) = None;
}

"""Full spec for one HTTP-activated scale target: its Service, routing rules,
scaling metric (concurrency or request-rate), cold-start behavior, and timeouts."""
obj HTTPActivationSpec {
    has name: str,
        namespace: str,
        scale_target_name: str,
        target: HTTPServiceTarget,
        scale_target_api_version: str = "apps/v1",
        scale_target_kind: str = "Deployment",
        rules: list[HTTPRoutingRule] = [],
        min_replicas: int = 0,
        max_replicas: int = 1,
        polling_interval: int = 30,
        cooldown_period: int = 300,
        concurrency: (HTTPConcurrencyMetric | None) = None,
        request_rate: (HTTPRequestRateMetric | None) = None,
        cold_start: (HTTPColdStartSpec | None) = None,
        timeouts: (HTTPTimeoutSpec | None) = None;
}
