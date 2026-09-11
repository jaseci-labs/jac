import from jaclang.scale.runtime.context.util {
    k8s_safe_service_name,
    k8s_service_dns_host
}

glob KEDA_INTERCEPTOR_SERVICE_ADDRESS: str = "keda-add-ons-http-interceptor-proxy.keda:8080";


obj ServiceRoute {
    has url: str,
        host_header: (str | None) = None;
}


def resolve_interceptor_service_address(kubernetes_cfg: dict[str, any]) -> str {
    """The one place that decides which interceptor address a deployment
    uses: [scale.kubernetes.http_activation].interceptor_service_address when
    set, KEDA_INTERCEPTOR_SERVICE_ADDRESS otherwise. Every KEDAAutoscaler
    construction site and the runtime routing resolver below both go through
    this, so neither can point at an interceptor the other does not.""";
    http_cfg: dict[str, any] = dict(kubernetes_cfg.get("http_activation", {}));
    return str(
        http_cfg.get("interceptor_service_address", KEDA_INTERCEPTOR_SERVICE_ADDRESS)
    );
}


def resolve_http_activation_config(
    top_level_http_activation: dict[str, any], app_scale_cfg: dict[str, any]
) -> dict[str, any] | None {
    """Merge [apps.<svc_name>.scale.http_activation] over
    [scale.kubernetes.http_activation]. The single implementation of this
    precedence; ManifestBuilder._get_http_activation_config delegates here.
    Returns None when the merged config isn't enabled.""";
    per_service: dict[str, any] = dict(app_scale_cfg.get("http_activation", {}));
    merged: dict[str, any] = dict(top_level_http_activation);
    merged.update(per_service);
    if not merged.get("enabled", False) {
        return None;
    }
    return merged;
}


def resolve_service_route(
    svc_name: str,
    namespace: str,
    port: int,
    kubernetes_cfg: dict[str, any],
    app_scale_cfg: dict[str, any]
) -> ServiceRoute {
    """The one decision point: interceptor-routed vs. direct ClusterIP.""";
    safe_name = k8s_safe_service_name(svc_name);
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
