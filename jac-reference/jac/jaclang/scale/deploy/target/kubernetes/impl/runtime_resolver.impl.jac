impl resolve_peer_route(svc_name: str, namespace: str, port: int) -> ServiceRoute {
    `override: str = sv_client.peer_url_from_env(svc_name);
    if `override {
        return ServiceRoute(url=`override, host_header=None);
    }
    key: str = sv_client.peer_url_env_key(svc_name);
    if key in os.environ {
        logger.debug(
            f"{key} is set but blank; resolving '{svc_name}' by naming convention"
        );
    }
    kubernetes_cfg: dict[str, any] = {};
    app_scale_cfg: dict[str, any] = {};
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        scale_cfg = get_scale_config();
        kubernetes_cfg = scale_cfg.get_kubernetes_config();
        app_scale_cfg = scale_cfg.get_app_scale_config(svc_name);
        _config_load_warned.discard(svc_name);
    } except Exception as e {
        if svc_name not in _config_load_warned {
            _config_load_warned.add(svc_name);
            logger.warning(
                f"Could not load scale config while resolving '{svc_name}'; "
                f"treating it as not HTTP-activated: {e}"
            );
        }
    }
    return resolve_service_route(
        svc_name, namespace, port, kubernetes_cfg, app_scale_cfg
    );
}

impl build_k8s_registry_routes(
    routes: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, ServiceRoute] {
    namespace: str = in_cluster_namespace();
    result: dict[str, ServiceRoute] = {};
    for svc_name in list(routes) {
        result[str(svc_name)] = resolve_peer_route(str(svc_name), namespace, port);
    }
    return result;
}

impl build_k8s_registry(
    apps: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str] {
    return {
        name: route.url
        for (name, route) in build_k8s_registry_routes(apps, port).items()
    };
}
