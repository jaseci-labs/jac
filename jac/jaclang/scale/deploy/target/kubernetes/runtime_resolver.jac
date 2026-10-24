import os;
import logging;

import from jaclang.server { sv_client }

glob logger = logging.getLogger(__name__),
     _config_load_warned: set[str] = set();


def resolve_peer_route(svc_name: str, namespace: str, port: int) -> ServiceRoute;


def resolve_peer_url(svc_name: str, namespace: str, port: int) -> str;


obj K8sRuntimeServiceResolver(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "kubernetes",
        namespace: str = "default",
        port: int = DEFAULT_GATEWAY_PORT;

    def url_for(service_entry: ServiceEntry) -> str;
    def deploy_service(name: str) -> bool;
    def stop_service(name: str) -> bool;
    def restart_service(name: str) -> bool;
    def scale_service(name: str, replicas: int) -> bool;
    def status -> dict[str, dict[str, any]];
    def get_logs(name: str, lines: int = 50) -> str;
    def destroy_all -> bool;
    def deploy_all -> bool;
}


def build_k8s_registry_routes(
    routes: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, ServiceRoute];


def build_k8s_registry(
    apps: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str];
