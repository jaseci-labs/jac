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
            f"service '{module_name}' derives the route '/{slug}', which collides " + f"with a builtin gateway segment. Rename the service module so its " + f"route does not shadow a builtin path."
        );
    }
}


def format_route_origin_lines(
    routes: dict[str, str], explicit_routes: dict[str, str]
) -> list[str] {
    names = sorted(routes.keys());
    configured = [
        n
        for n in names
        if n in explicit_routes
    ];
    derived = [
        n
        for n in names
        if n not in explicit_routes
    ];
    lines: list[str] = [];
    if configured {
        pairs = ", ".join([f"{n} -> {routes[n]}" for n in configured]);
        lines.append(f"configured:   {pairs}");
    }
    if derived {
        pairs = ", ".join([f"{n} -> {routes[n]}" for n in derived]);
        lines.append(f"auto-derived: {pairs}");
    }
    return lines;
}
