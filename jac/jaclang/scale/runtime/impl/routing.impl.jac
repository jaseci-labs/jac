impl _derive_builtin_prefixes -> tuple[str, ...] {
    segs = [GATEWAY_CLIENT_SEGMENT] + list(GATEWAY_API_SEGMENTS);
    return tuple([f"/{seg}/" for seg in segs]);
}

impl _derive_service_owned_segments -> tuple[str, ...] {
    shared = set(GATEWAY_DISCOVERY_SEGMENTS) | set(GATEWAY_REPLICATED_SEGMENTS);
    return tuple(
        [
            seg
            for seg in GATEWAY_API_SEGMENTS
            if seg not in shared
        ]
    );
}

impl is_learnable_prefix(prefix: str) -> bool {
    segs = prefix.strip("/").split("/");
    head = segs[0];
    if head not in _GATEWAY_OWNED_PREFIX_SEGMENTS {
        return True;
    }
    return head in GATEWAY_SERVICE_OWNED_SEGMENTS and len(segs) > 1;
}

impl is_gateway_owned_segment(segment: str) -> bool {
    return segment in _GATEWAY_OWNED_PREFIX_SEGMENTS;
}

impl guard_route_prefix(name: str, prefix: str) {
    seg = prefix.strip("/").split("/")[0];
    if seg in _GATEWAY_OWNED_PREFIX_SEGMENTS {
        raise ValueError(
            f"app '{name}' maps to route '{prefix}', whose first segment "
                + f"'/{seg}' is owned by the gateway. Set [apps.{name}] route to "
                + f"a prefix that does not shadow a builtin path."
        );
    }
}

impl format_route_lines(routes: dict[str, str]) -> list[str] {
    names = sorted(routes.keys());
    if not names {
        return [];
    }
    pairs = ", ".join([f"{n} -> {routes[n]}" for n in names]);
    return [f"routes: {pairs}"];
}
