import logging;
import os;

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def colocated_providers -> dict[str, any];


def provider_route(config: any, provider_app: str) -> str;


def _body(request: Request) -> (dict[str, any] | None);


def _fail(code: str, message: str, status: int) -> TransportResponse;


def _unit_failed(result: any) -> bool;


def _outcome(result: any, fallback: str) -> (TransportResponse | Response);


def _walker_callback(
    server: JacAPIServer,
    provider_app: str,
    walker_name: str,
    intro: ModuleIntrospector,
    requires_auth: bool
) -> Callable[..., (TransportResponse | Response)];


def _function_callback(
    server: JacAPIServer,
    provider_app: str,
    func_name: str,
    intro: ModuleIntrospector,
    requires_auth: bool
) -> Callable[..., (TransportResponse | Response)];


def _listing(names: list[str], key: str) -> Callable[..., TransportResponse];


def _mount_provider(
    server: JacAPIServer, provider_app: str, route: str, intro: ModuleIntrospector
);


def served_app_route(server: JacAPIServer) -> tuple[str, str, any];

def provider_introspector(
    server: JacAPIServer, provider_app: str, provider_module: any
) -> (ModuleIntrospector | None);

def register_colocated_endpoints(server: JacAPIServer);
