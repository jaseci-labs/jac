glob GATEWAY_API_SEGMENTS: tuple[str, ...] = (
         "walker",
         "function",
         "user",
         "sso",
         "api-key",
         "webhook",
         "ws",
         "jobs",
         "graph"
     ),
     GATEWAY_BARE_API_SEGMENTS: tuple[str, ...] = ("user", "graph", "jobs"),
     GATEWAY_CLIENT_SEGMENT: str = "cl",
     GATEWAY_WELLKNOWN_SEGMENTS: tuple[str, ...] = (
         "health",
         "healthz",
         "metrics",
         "openapi.json",
         "docs"
     ),
     GATEWAY_PAGE_SEGMENTS: tuple[str, ...] = ("docs", ),
     GATEWAY_DISCOVERY_SEGMENTS: tuple[str, ...] = ("jobs", GATEWAY_CLIENT_SEGMENT),
     GATEWAY_REPLICATED_SEGMENTS: tuple[str, ...] = ("user", "sso", "api-key", "graph"),
     GATEWAY_LISTING_SEGMENTS: tuple[str, ...] = ("walkers", "functions"),
     _GATEWAY_OWNED_PREFIX_SEGMENTS: set[str] = (
         set(GATEWAY_API_SEGMENTS)
         | set(GATEWAY_WELLKNOWN_SEGMENTS)
         | {GATEWAY_CLIENT_SEGMENT, "admin", "static"}
     );


def _derive_builtin_prefixes -> tuple[str, ...];


def _derive_service_owned_segments -> tuple[str, ...];


glob GATEWAY_BUILTIN_PREFIXES: tuple[str, ...] = _derive_builtin_prefixes(),
     GATEWAY_BARE_API_PATHS: set[str] = {
         f"/{seg}" for seg in GATEWAY_BARE_API_SEGMENTS
     },
     GATEWAY_SERVICE_OWNED_SEGMENTS: tuple[str, ...] = _derive_service_owned_segments();


def is_learnable_prefix(prefix: str) -> bool;


def is_gateway_owned_segment(segment: str) -> bool;


def guard_route_prefix(name: str, prefix: str);


def format_route_lines(routes: dict[str, str]) -> list[str];
