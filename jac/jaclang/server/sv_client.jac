import os;

glob BRIDGE_TOKEN_ENV: str = "JAC_BRIDGE_TOKEN",
     BRIDGE_USERNAME: str = "__bridge__",
     IDEMPOTENCY_HEADER: str = "X-Jac-Idempotency-Key",
     _registry: dict[str, str] = {},
     _routes: dict[str, str] = {},
     _base_routes: dict[str, str] = {},
     _test_clients: dict[str, any] = {},
     _local_providers: dict[str, any] = {},
     _consumer_providers: dict[str, list[str]] = {},
     _bearer_token: list[str] = [],
     _consumer_app: list[str] = [],
     _read_cache: dict[tuple[str, str, str, str], any] = {},
     _read_cache_flags: list[any] = [],
     _cache_epoch: list[int] = [0],
     _active_writes: dict[str, int] = {};

def headless_start_args(entry_file: str, port: int) -> list[str];

def app_start_args(
    entry_file: str, port: int, dev: bool = False, api_port: int = 0
) -> list[str];

def register(app: str, url: str, route: str = "");

def unregister(app: str);

def registered_route(app: str) -> str;

def register_local(app: str, module: any);

def unregister_local(app: str);

def is_local(app: str) -> bool;

def register_test_client(app: str, client: any);

def clear_test_clients;

def clear_local_providers;

def set_bearer_token(token: str);

def bearer_token -> str;

def bridge_identity(authorization: (str | None)) -> str;

def set_consumer_app(name: str);

def consumer_app -> str;

def clear_read_cache(app: str = "");

def _read_cache_enabled -> bool;

def _read_cache_key(
    app: str, fn: str, kwargs: dict[str, any]
) -> tuple[str, str, str, str];

def auth_headers -> dict[str, str];

def request_headers(idempotency_key: str = "") -> dict[str, str];

def has_consumers -> bool;

def _declare_consumer_provider(consumer_app: str, provider_app: str, route: str = "");

def get_consumer_providers(consumer_app: str) -> list[str];

def clear_consumer_providers;

def provider_route(app: str) -> str;

def peer_url_env_key(app: str) -> str;

def peer_route_env_key(app: str) -> str;

def peer_url_from_env(app: str) -> str;

def _unavailable(app: str, name: str = "") -> BridgeUnavailable;

def resolve_url(app: str) -> str;

def _ensure_available(app: str, name: str = "") -> None;

def _scale_transport -> any;

def _unwrap_envelope(data: any, app: str, name: str) -> any;

def _http_call(
    app: str, fn: str, kwargs: dict[str, any], headers: dict[str, str]
) -> any;

def function_result(data: any, app: str, fn: str) -> any;

def hydrate_walker_envelope(
    data: any, app: str, walker_name: str, stub_cls: any
) -> any;

def _http_spawn(
    app: str,
    walker_name: str,
    kwargs: dict[str, any],
    stub_cls: any,
    headers: dict[str, str]
) -> any;

async def _await_if_needed(value: any) -> any;

async def _local_call(app: str, fn: str, kwargs: dict[str, any]) -> any;

async def _local_spawn(app: str, walker_name: str, kwargs: dict[str, any]) -> any;

async def call(
    app: str,
    fn: str,
    kwargs: dict[str, any],
    effects: (list[str] | None) = None,
    contract: str = ""
) -> any;

async def spawn_walker(
    app: str,
    walker_name: str,
    kwargs: dict[str, any],
    stub_cls: any,
    idempotency_key: str = ""
) -> any;

def spawn_deferred(
    app: str, walker_name: str, kwargs: dict[str, any], idempotency_key: str = ""
) -> str;

def ensure_all(apps: list[str]);
