import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPActivationSpec,
    HTTPServiceTarget,
    HTTPConcurrencyMetric,
    HTTPRequestRateMetric,
    HTTPStaticResponse,
    HTTPColdStartSpec,
    HTTPTimeoutSpec,
    HTTPRoutingRule,
    HTTPPathMatch,
    HTTPHeaderMatch
}
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from kubernetes.client.exceptions { ApiException }

def build_http_activation_spec(
    cfg: dict[str, any], scale_target_name: str, namespace: str, service_name: str
) -> HTTPActivationSpec | None {
    if not cfg.get("enabled", False) {
        return None;
    }

    target_port = cfg.get("target_port");
    target_port_name = cfg.get("target_port_name");
    if target_port is not None and target_port_name is not None {
        raise ValueError(
            "[*.http_activation]: set exactly one of target_port or "
            "target_port_name, not both."
        );
    }
    if target_port is None and target_port_name is None {
        raise ValueError(
            "[*.http_activation]: set exactly one of target_port or "
            "target_port_name."
        );
    }

    concurrency_target = cfg.get("concurrency_target");
    request_rate_target = cfg.get("request_rate_target");
    if concurrency_target is None and request_rate_target is None {
        raise ValueError(
            "[*.http_activation]: set at least one of concurrency_target or "
            "request_rate_target."
        );
    }

    concurrency = None;
    if concurrency_target is not None {
        concurrency = HTTPConcurrencyMetric(target_value=concurrency_target);
    }
    request_rate = None;
    if request_rate_target is not None {
        request_rate = HTTPRequestRateMetric(
            target_value=request_rate_target,
            window=cfg.get("request_rate_window", "1m"),
            granularity=cfg.get("request_rate_granularity", "1s")
        );
    }

    rules: list[HTTPRoutingRule] = [];
    for rule in cfg.get("rules", []) {
        rules.append(
            HTTPRoutingRule(
                hosts=list(rule.get("hosts", [])),
                paths=[HTTPPathMatch(value=p) for p in rule.get("paths", [])],
                headers=[
                    HTTPHeaderMatch(name=h["name"], value=h.get("value"))
                    for h in rule.get("headers", [])
                ]
            )
        );
    }

    placeholder = None;
    has_placeholder = (
        "cold_start_body" in cfg
        or "cold_start_body_config_map" in cfg
        or "cold_start_headers" in cfg
        or "cold_start_status_code" in cfg
    );
    if has_placeholder {
        placeholder = HTTPStaticResponse(
            status_code=cfg.get("cold_start_status_code", 503),
            body=cfg.get("cold_start_body"),
            body_from_config_map=cfg.get("cold_start_body_config_map"),
            headers=cfg.get("cold_start_headers", {})
        );
    }
    fallback_service = None;
    if "cold_start_fallback_service" in cfg {
        fallback_service = HTTPServiceTarget(
            service=str(cfg.get("cold_start_fallback_service", "")),
            port=cfg.get("cold_start_fallback_port")
        );
    }
    cold_start = None;
    if placeholder is not None or fallback_service is not None {
        cold_start = HTTPColdStartSpec(
            placeholder=placeholder, fallback_service=fallback_service
        );
    }

    timeouts = None;
    has_timeouts = (
        "timeout_readiness" in cfg
        or "timeout_request" in cfg
        or "timeout_response_header" in cfg
    );
    if has_timeouts {
        timeouts = HTTPTimeoutSpec(
            readiness=cfg.get("timeout_readiness"),
            request=cfg.get("timeout_request"),
            response_header=cfg.get("timeout_response_header")
        );
    }

    return HTTPActivationSpec(
        name=scale_target_name,
        namespace=namespace,
        scale_target_name=scale_target_name,
        target=HTTPServiceTarget(
            service=service_name, port=target_port, port_name=target_port_name
        ),
        scale_target_api_version=cfg.get("scale_target_api_version", "apps/v1"),
        scale_target_kind=cfg.get("scale_target_kind", "Deployment"),
        scale_target_plural=cfg.get("scale_target_plural"),
        rules=rules,
        min_replicas=cfg.get("min_replicas", 0),
        max_replicas=cfg.get("max_replicas", 1),
        polling_interval=cfg.get("polling_interval", 30),
        cooldown_period=cfg.get("cooldown_period", 300),
        concurrency=concurrency,
        request_rate=request_rate,
        cold_start=cold_start,
        timeouts=timeouts
    );
}

def apply_http_activation_for_target(
    cfg: dict[str, any],
    scale_target_name: str,
    namespace: str,
    service_name: str,
    keda: KEDAAutoscaler
) -> bool | None {
    spec = build_http_activation_spec(cfg, scale_target_name, namespace, service_name);
    if spec is None {
        return None;
    }
    return keda.apply_http_activation(spec);
}

def destroy_http_activation_for_target(
    scale_target_name: str, namespace: str, keda: KEDAAutoscaler
) {
    try {
        keda.destroy_http_activation(scale_target_name, namespace);
    } except ApiException as e {
        if keda.logger {
            keda.logger.warn(
                "Failed to clean up HTTP activation resources for "
                f"'{scale_target_name}' in '{namespace}': {e}. Continuing "
                "with the rest of teardown; manual cleanup of the "
                "InterceptorRoute/ScaledObject may be required."
            );
        }
    }
}
