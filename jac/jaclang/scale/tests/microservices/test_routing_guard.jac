import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config { get_config }
import from jaclang.scale.runtime.routing {
    ensure_main_service,
    guard_route_name,
    is_reserved,
    resolve_routes,
    is_learnable_prefix,
    GATEWAY_API_SEGMENTS,
    GATEWAY_WELLKNOWN_SEGMENTS,
    GATEWAY_CLIENT_SEGMENT,
    GATEWAY_BUILTIN_PREFIXES,
    GATEWAY_DISCOVERY_SEGMENTS,
    GATEWAY_REPLICATED_SEGMENTS,
    GATEWAY_SERVICE_OWNED_SEGMENTS
}


test "a service named cl is rejected instead of silently shadowed" {
    caught = False;
    try {
        guard_route_name("cl");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "the _app suffix does not evade the reserved guard" {
    caught = False;
    try {
        guard_route_name("cl_app");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "every gateway-owned segment is reserved as a route name" {
    for seg in GATEWAY_API_SEGMENTS {
        assert is_reserved(seg);
    }
    for seg in GATEWAY_WELLKNOWN_SEGMENTS {
        assert is_reserved(seg);
    }
    assert is_reserved(GATEWAY_CLIENT_SEGMENT);
}


test "a user-supplied prefix under a gateway segment is rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"myapp": "/admin"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "a nested prefix under a gateway segment is rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"myapp": "user/panel"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "two services resolving to the same prefix are rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"a": "/shop", "b": "shop"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "valid routes still resolve with derived and normalized prefixes" {
    routes = resolve_routes({"routes": {"orders": "", "billing": "pay"}});
    assert routes == {"orders": "/orders", "billing": "/pay"};
}


test "a prefix under a name-reserved but unowned segment is allowed" {
    routes = resolve_routes({"routes": {"cart": "/api/cart"}});
    assert routes == {"cart": "/api/cart"};
}


test "trailing slashes cannot evade the duplicate-prefix check" {
    caught = False;
    try {
        resolve_routes({"routes": {"a": "/shop", "b": "/shop/"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "a trailing slash is canonicalized off the stored prefix" {
    routes = resolve_routes({"routes": {"shop": "/shop/"}});
    assert routes == {"shop": "/shop"};
}


test "every builtin gateway prefix is reserved as a route name" {
    assert "/cl/" in GATEWAY_BUILTIN_PREFIXES;
    for prefix in GATEWAY_BUILTIN_PREFIXES {
        assert is_reserved(prefix.strip("/"));
    }
}


test "builtin families partition the API segments the guard reserves" {
    discovery = set(GATEWAY_DISCOVERY_SEGMENTS);
    replicated = set(GATEWAY_REPLICATED_SEGMENTS);
    owned = set(GATEWAY_SERVICE_OWNED_SEGMENTS);
    assert not (discovery & replicated);
    assert not (owned & (discovery | replicated));
    assert owned | replicated | (discovery - {GATEWAY_CLIENT_SEGMENT})
        == set(GATEWAY_API_SEGMENTS);
    assert GATEWAY_CLIENT_SEGMENT in discovery;
    for seg in ["walker", "function", "webhook"] {
        assert seg in owned;
    }
}


test "only concrete members of service-owned families are learnable" {
    assert is_learnable_prefix("/walker/create_user");
    assert is_learnable_prefix("/api/orders");
    for prefix in [
        "/walker",
        "/function",
        "/webhook",
        "/cl",
        "/cl/dashboard",
        "/user/login",
        "/sso/firebase/token",
        "/api-key/create",
        "/jobs",
        "/graph/data",
        "/healthz/live",
        "/admin/users"
    ] {
        assert not is_learnable_prefix(prefix) , (
            f"{prefix} must never be handed to a single service"
        );
    }
}


test "the main service takes its filename from the project entry point" {
    project_dir = Path(tempfile.mkdtemp(prefix="jac-entrypoint-"));
    (project_dir / "jac.toml").write_text(
        '[project]\n' 'name = "entrypointread"\n' 'entry-point = "app.jac"\n',
        encoding="utf-8"
    );
    (project_dir / "app.jac").write_text("with entry {}\n", encoding="utf-8");
    routes: dict[str, str] = {"orders": "/orders"};
    service_files: dict[str, str] = {"orders": "orders.jac"};
    try {
        get_config(start_path=project_dir, force_discover=True);
        ensure_main_service(routes, service_files);
        assert service_files["main"] == "app.jac";
    } finally {
        get_config(force_discover=True);
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}
