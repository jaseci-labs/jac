glob GATEWAY_API_SEGMENTS: tuple = (
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
     GATEWAY_BARE_API_SEGMENTS: tuple = ("user", "graph", "jobs"),
     GATEWAY_CLIENT_SEGMENT: str = "cl",
     GATEWAY_WELLKNOWN_SEGMENTS: tuple = (
         "health",
         "healthz",
         "metrics",
         "openapi.json",
         "docs"
     ),
     GATEWAY_PAGE_SEGMENTS: tuple = ("docs", ),
     GATEWAY_DISCOVERY_SEGMENTS: tuple = ("jobs", GATEWAY_CLIENT_SEGMENT),
     GATEWAY_REPLICATED_SEGMENTS: tuple = ("user", "sso", "api-key", "graph"),
     GATEWAY_LISTING_SEGMENTS: tuple = ("walkers", "functions"),
     _GATEWAY_OWNED_PREFIX_SEGMENTS: set[str] = (
         set(GATEWAY_API_SEGMENTS)
         | set(GATEWAY_WELLKNOWN_SEGMENTS)
         | {GATEWAY_CLIENT_SEGMENT, "admin", "static"}
     );


def _derive_builtin_prefixes -> tuple {
    segs = [GATEWAY_CLIENT_SEGMENT] + list(GATEWAY_API_SEGMENTS);
    return tuple([f"/{seg}/" for seg in segs]);
}


def _derive_service_owned_segments -> tuple {
    shared = set(GATEWAY_DISCOVERY_SEGMENTS) | set(GATEWAY_REPLICATED_SEGMENTS);
    return tuple(
        [
            seg
            for seg in GATEWAY_API_SEGMENTS
            if seg not in shared
        ]
    );
}


glob GATEWAY_BUILTIN_PREFIXES: tuple = _derive_builtin_prefixes(),
     GATEWAY_BARE_API_PATHS: set[str] = {
         f"/{seg}" for seg in GATEWAY_BARE_API_SEGMENTS
     },
     GATEWAY_SERVICE_OWNED_SEGMENTS: tuple = _derive_service_owned_segments();


def is_learnable_prefix(prefix: str) -> bool {
    segs = prefix.strip("/").split("/");
    head = segs[0];
    if head not in _GATEWAY_OWNED_PREFIX_SEGMENTS {
        return True;
    }
    return head in GATEWAY_SERVICE_OWNED_SEGMENTS and len(segs) > 1;
}


def is_gateway_owned_segment(segment: str) -> bool {
    return segment in _GATEWAY_OWNED_PREFIX_SEGMENTS;
}


def guard_route_prefix(name: str, prefix: str) {
    seg = prefix.strip("/").split("/")[0];
    if seg in _GATEWAY_OWNED_PREFIX_SEGMENTS {
        raise ValueError(
            f"app '{name}' maps to route '{prefix}', whose first segment "
                + f"'/{seg}' is owned by the gateway. Set [apps.{name}] route to "
                + f"a prefix that does not shadow a builtin path."
        );
    }
}


def format_route_lines(routes: dict[str, str]) -> list[str] {
    names = sorted(routes.keys());
    if not names {
        return [];
    }
    pairs = ", ".join([f"{n} -> {routes[n]}" for n in names]);
    return [f"routes: {pairs}"];
}
