glob _RESERVED_SEGMENTS: set[str] = {
         "api",
         "walker",
         "function",
         "user",
         "sso",
         "api-key",
         "webhook",
         "ws",
         "jobs",
         "graph",
         "admin",
         "static",
         "health",
         "healthz",
         "metrics",
         "openapi.json",
         "docs"
     };


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


def resolve_routes(ms_config: dict[str, any]) -> dict[str, str] {
    routes_cfg = dict(ms_config.get("routes", {}) or {});
    routes: dict[str, str] = {};
    for (name, prefix) in routes_cfg.items() {
        name_str: str = str(name);
        guard_route_name(name_str);
        prefix_str: str = str(prefix or "");
        if not prefix_str {
            prefix_str = derive_route_prefix(name_str);
        } elif not prefix_str.startswith("/") {
            prefix_str = "/" + prefix_str;
        }
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
