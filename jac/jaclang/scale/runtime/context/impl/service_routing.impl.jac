impl resolve_interceptor_service_address(kubernetes_cfg: dict[str, any]) -> str {
    http_cfg: dict[str, any] = dict(kubernetes_cfg.get("http_activation", {}));
    return str(
        http_cfg.get("interceptor_service_address", KEDA_INTERCEPTOR_SERVICE_ADDRESS)
    );
}

impl resolve_http_activation_config(
    top_level_http_activation: dict[str, any], app_scale_cfg: dict[str, any]
) -> dict[str, any] | None {
    per_service: dict[str, any] = dict(app_scale_cfg.get("http_activation", {}));
    merged: dict[str, any] = dict(top_level_http_activation);
    merged.update(per_service);
    if not merged.get("enabled", False) {
        return None;
    }
    return merged;
}

impl resolve_service_route(
    svc_name: str,
    namespace: str,
    port: int,
    kubernetes_cfg: dict[str, any],
    app_scale_cfg: dict[str, any]
) -> ServiceRoute {
    safe_name = k8s_safe_name(svc_name);
    real_host = k8s_service_dns_host(f"{safe_name}-service", namespace);
    http_cfg = resolve_http_activation_config(
        dict(kubernetes_cfg.get("http_activation", {})), app_scale_cfg
    );
    if http_cfg is not None {
        interceptor_address = resolve_interceptor_service_address(kubernetes_cfg);
        return ServiceRoute(url=f"http://{interceptor_address}", host_header=real_host);
    }
    return ServiceRoute(url=f"http://{real_host}:{port}", host_header=None);
}

impl is_http_activated(app_name: str) -> bool {
    if not app_name {
        return False;
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        scale_cfg = get_scale_config();
        kubernetes_cfg = scale_cfg.get_kubernetes_config();
        app_scale_cfg = scale_cfg.get_app_scale_config(app_name);
    } except Exception {
        return False;
    }
    return resolve_http_activation_config(
        dict(kubernetes_cfg.get("http_activation", {})), app_scale_cfg
    )
        is not None;
}
