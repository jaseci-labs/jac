import os;
import logging;

import from jaclang.server { sv_client }

glob logger = logging.getLogger(__name__),
     _config_load_warned: set[str] = set();


def resolve_peer_route(svc_name: str, namespace: str, port: int) -> ServiceRoute;


def build_k8s_registry_routes(
    routes: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, ServiceRoute];


def build_k8s_registry(
    apps: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str];
