glob KEDA_INTERCEPTOR_SERVICE_ADDRESS: str = "keda-add-ons-http-interceptor-proxy.keda:8080",
     HTTP_ACTIVATED_WAKE_TIMEOUT: float = 300.0;


obj ServiceRoute {
    has url: str,
        host_header: (str | None) = None;
}


def resolve_interceptor_service_address(kubernetes_cfg: dict[str, any]) -> str;


def resolve_http_activation_config(
    top_level_http_activation: dict[str, any], app_scale_cfg: dict[str, any]
) -> dict[str, any] | None;


def resolve_service_route(
    svc_name: str,
    namespace: str,
    port: int,
    kubernetes_cfg: dict[str, any],
    app_scale_cfg: dict[str, any]
) -> ServiceRoute;


def is_http_activated(app_name: str) -> bool;
