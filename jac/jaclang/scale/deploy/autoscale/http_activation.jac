obj HTTPPathMatch {
    has value: str;
}

obj HTTPHeaderMatch {
    has name: str,
        value: (str | None) = None;
}

obj HTTPRoutingRule {
    has hosts: list[str] = [],
        paths: list[HTTPPathMatch] = [],
        headers: list[HTTPHeaderMatch] = [];
}

obj HTTPServiceTarget {
    has service: str,
        port: (int | None) = None,
        port_name: (str | None) = None;
}

obj HTTPConcurrencyMetric {
    has target_value: int;
}

obj HTTPRequestRateMetric {
    has target_value: int,
        window: str = "1m",
        granularity: str = "1s";
}

obj HTTPStaticResponse {
    has status_code: int = 503,
        body: (str | None) = None,
        body_from_config_map: (dict[str, str] | None) = None,
        headers: dict[str, str] = {};
}

obj HTTPColdStartSpec {
    has placeholder: (HTTPStaticResponse | None) = None,
        fallback_service: (HTTPServiceTarget | None) = None;
}

obj HTTPTimeoutSpec {
    has readiness: (str | None) = None,
        request: (str | None) = None,
        response_header: (str | None) = None;
}

obj HTTPActivationSpec {
    has name: str,
        namespace: str,
        scale_target_name: str,
        target: HTTPServiceTarget,
        scale_target_api_version: str = "apps/v1",
        scale_target_kind: str = "Deployment",
        scale_target_plural: (str | None) = None,
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
