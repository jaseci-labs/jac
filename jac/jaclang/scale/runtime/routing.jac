import os;

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
     GATEWAY_DISCOVERY_SEGMENTS: tuple = ("jobs", GATEWAY_CLIENT_SEGMENT),
     GATEWAY_REPLICATED_SEGMENTS: tuple = ("user", "sso", "api-key", "graph"),
     _RESERVED_SEGMENTS: set[str] = (
         set(GATEWAY_API_SEGMENTS)
         | set(GATEWAY_WELLKNOWN_SEGMENTS)
         | {GATEWAY_CLIENT_SEGMENT, "api", "admin", "static"}
     ),
     _GATEWAY_OWNED_PREFIX_SEGMENTS: set[str] = (
         set(GATEWAY_API_SEGMENTS)
         | set(GATEWAY_WELLKNOWN_SEGMENTS)
         | {GATEWAY_CLIENT_SEGMENT, "admin"}
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


def service_slug(module_name: str) -> str {
    name = module_name;
    if name.endswith("_app") {
        name = name[:-4];
    }
    return name;
}


def derive_route_prefix(module_name: str) -> str {
    return f"/{service_slug(module_name)}";
}


def is_reserved(module_name: str) -> bool {
    return service_slug(module_name) in _RESERVED_SEGMENTS;
}


def guard_route_name(module_name: str) {
    if is_reserved(module_name) {
        slug = service_slug(module_name);
        raise ValueError(
            f"service '{module_name}' derives the route '/{slug}', which collides "
                + f"with a builtin gateway segment. Rename the service module so its "
                + f"route does not shadow a builtin path."
        );
    }
}


def guard_route_prefix(name: str, prefix: str) {
    seg = prefix.strip("/").split("/")[0];
    if seg in _GATEWAY_OWNED_PREFIX_SEGMENTS {
        raise ValueError(
            f"service '{name}' maps to route prefix '{prefix}', whose first "
                + f"segment '/{seg}' is owned by the gateway. Choose a prefix "
                + f"that does not shadow a builtin path."
        );
    }
}


def ensure_main_service(
    routes: dict[str, str], service_files: dict[str, str], entry_file: str = ''
) -> None {
    if 'main' in routes {
        return;
    }
    for prefix in routes.values() {
        if prefix in ('/', '/__main__') {
            return;
        }
    }
    if not entry_file {
        try {
            import from jaclang.project.config { get_config }
            cfg = get_config();
            entry_file = str((cfg.project.entry_point if cfg else '') or 'main.jac');
        } except Exception {
            entry_file = 'main.jac';
        }
    }
    routes['main'] = '/__main__';
    service_files['main'] = os.path.basename(entry_file);
}


def resolve_routes(ms_config: dict[str, any]) -> dict[str, str] {
    routes_cfg = dict(ms_config.get("routes", {}) or {});
    routes: dict[str, str] = {};
    owners: dict[str, str] = {};
    for (name, prefix) in routes_cfg.items() {
        name_str: str = str(name);
        guard_route_name(name_str);
        prefix_str: str = str(prefix or "");
        if not prefix_str {
            prefix_str = derive_route_prefix(name_str);
        } else {
            prefix_str = "/" + prefix_str.strip("/");
        }
        guard_route_prefix(name_str, prefix_str);
        if prefix_str in owners {
            raise ValueError(
                f"services '{owners[prefix_str]}' and '{name_str}' both resolve "
                    + f"to route prefix '{prefix_str}'; every service needs a "
                    + f"distinct prefix."
            );
        }
        owners[prefix_str] = name_str;
        routes[name_str] = prefix_str;
    }
    return routes;
}


def resolve_service_files(
    ms_config: dict[str, any], routes: dict[str, str]
) -> dict[str, str] {
    services_cfg = dict(ms_config.get("services", {}) or {});
    out: dict[str, str] = {};
    for name in routes {
        svc = dict(services_cfg.get(name, {}) or {});
        out[name] = str(svc.get("file") or f"{name}.jac");
    }
    return out;
}


def should_enter_local_ms(
    enabled: bool | None, is_sv_sibling: bool, scale_flag: bool, has_services: bool
) -> bool {
    if is_sv_sibling or scale_flag or (enabled is False) {
        return False;
    }
    if enabled is True {
        return True;
    }
    return has_services;
}


def format_route_lines(routes: dict[str, str]) -> list[str] {
    names = sorted(routes.keys());
    if not names {
        return [];
    }
    pairs = ", ".join([f"{n} -> {routes[n]}" for n in names]);
    return [f"routes: {pairs}"];
}
