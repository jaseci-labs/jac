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

# Translates a [scale.kubernetes.http_activation] / [scale.microservices.
# services.NAME.http_activation] config dict into an HTTPActivationSpec, or
# None when the block is absent/disabled. Raises ValueError with jac.toml-
# relative messages for the two hard requirements HTTPActivationSpec itself
# also enforces (KEDAAutoscaler._validate_http_activation_spec), so a config
# mistake points at the actual jac.toml key instead of an internal type name.
# Shared by both the monolith (kubernetes_target.jac) and microservices
# (manifest_builder.jac / microservice/target.jac) deploy paths.
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

# Deploy-path entry point shared by the monolith (kubernetes_target.jac) and
# microservices (manifest_builder.jac / microservice/target.jac) apply call
# sites. Takes the KEDAAutoscaler as an explicit parameter (rather than
# constructing one internally) so it stays unit-testable with a mocked
# instance, independent of whatever cluster-facing code calls it. Returns
# None (skip, nothing to report) when the config is disabled/absent, matching
# how build_http_activation_spec itself signals "nothing to do."
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

# Deploy-path teardown counterpart to apply_http_activation_for_target above.
# Deliberately unconditional, with no config parameter: gating on the
# *current* config would skip cleanup for a resource that was created while
# http_activation was enabled but later got disabled or removed from
# jac.toml, orphaning the InterceptorRoute/ScaledObject. destroy_http_
# activation is already 404-safe per-resource, so calling it unconditionally
# is always safe, mirroring how the base autoscaler's own destroy() call is
# unconditional at its call site.
#
# A non-404 ApiException (most plausibly a 403) is caught and logged rather
# than re-raised: the HTTP Add-on CRD group (http.keda.sh) installs
# separately from core KEDA, so a cluster's RBAC may cover keda.sh (already
# required for the base autoscaler) without yet covering this newer group.
# Letting that abort the caller's teardown would skip the Deployment,
# Service, PVC, ingress, monitoring, and database cleanup that follows it,
# for a resource kind that may not even be installed. This mirrors the
# warn-and-continue precedent already used by apply_http_activation's own
# HTTP Add-on preflight check.
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
