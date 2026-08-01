import os;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.scale.runtime.routing {
    derive_route_prefix,
    format_route_lines,
    guard_route_name,
    resolve_routes,
    resolve_service_files,
    should_enter_local_ms
}


test "resolve_routes reads the config cut verbatim" {
    ms = {"routes": {"orders_app": "/api/orders", "cart_app": "/cart"}};
    routes = resolve_routes(ms);
    assert routes == {"orders_app": "/api/orders", "cart_app": "/cart"};
}


test "resolve_routes derives a prefix for empty values" {
    routes = resolve_routes({"routes": {"orders_app": "", "littlex": ""}});
    assert routes == {"orders_app": "/orders", "littlex": "/littlex"};
}


test "resolve_routes normalizes a missing leading slash" {
    routes = resolve_routes({"routes": {"cart_app": "api/cart"}});
    assert routes == {"cart_app": "/api/cart"};
}


test "resolve_routes is empty when no cut is declared" {
    assert resolve_routes({}) == {};
    assert resolve_routes({"routes": {}}) == {};
}


test "resolve_routes rejects reserved service names" {
    raised = False;
    try {
        resolve_routes({"routes": {"admin": ""}});
    } except ValueError {
        raised = True;
    }
    assert raised , "reserved gateway segment must be rejected";
}


test "resolve_service_files honors services.<name>.file with a default" {
    ms = {
        "routes": {"social_graph": "/social", "orders_app": "/orders"},
        "services": {"social_graph": {"file": "littlex/social_graph.jac"}}
    };
    routes = resolve_routes(ms);
    files = resolve_service_files(ms, routes);
    assert files
        == {"social_graph": "littlex/social_graph.jac", "orders_app": "orders_app.jac"};
}


test "gate: explicit enabled=True always enters (config wins)" {
    assert should_enter_local_ms(True, False, False, False) == True;
    assert should_enter_local_ms(True, False, False, True) == True;
}


test "gate: explicit enabled=False never enters (opt-out honored)" {
    assert should_enter_local_ms(False, False, False, True) == False;
    assert should_enter_local_ms(False, False, False, False) == False;
}


test "gate: unset (None) enters on declared services" {
    assert should_enter_local_ms(None, False, False, True) == True;
}


test "gate: unset (None) stays monolith when nothing declared" {
    assert should_enter_local_ms(None, False, False, False) == False;
}


test "gate: sv sibling children never enter (no re-orchestration fork)" {
    assert should_enter_local_ms(True, True, False, True) == False;
    assert should_enter_local_ms(None, True, False, True) == False;
}


test "gate: --scale never takes the local path" {
    assert should_enter_local_ms(True, False, True, True) == False;
    assert should_enter_local_ms(None, False, True, True) == False;
}


test "format_route_lines reports the applied routes" {
    assert format_route_lines({"cart_app": "/api/cart", "orders_app": "/orders"})
        == ["routes: cart_app -> /api/cart, orders_app -> /orders"];
    assert format_route_lines({}) == [];
}


test "jac scale split declares a service in jac.toml" {
    import from jaclang.scale.plugin { _scale_split }

    with tempfile.TemporaryDirectory() as tmpdir {
        toml = Path(tmpdir) / "jac.toml";
        toml.write_text("[project]\nname = \"app\"\n");
        prev = os.getcwd();
        os.chdir(tmpdir);
        try {
            assert _scale_split("orders_app") == 0;
            assert _scale_split("orders_app") == 0;
            assert _scale_split("admin") == 1;
        } finally {
            os.chdir(prev);
        }
        with open(str(toml), "rb") as f {
            doc = tomllib.load(f);
        }
        routes = doc.get("scale", {}).get("microservices", {}).get("routes", {});
        assert routes == {"orders_app": "/orders"} , (
            f"split must write exactly one route entry, got {routes}"
        );
    }
}


test "jac scale split appends into an existing routes table" {
    import from jaclang.scale.plugin { _scale_split }

    with tempfile.TemporaryDirectory() as tmpdir {
        toml = Path(tmpdir) / "jac.toml";
        toml.write_text(
            "[project]\nname = \"app\"\n\n"
            "[scale.microservices.routes]\ncart_app = \"/api/cart\"\n"
        );
        prev = os.getcwd();
        os.chdir(tmpdir);
        try {
            assert _scale_split("orders_app") == 0;
        } finally {
            os.chdir(prev);
        }
        with open(str(toml), "rb") as f {
            doc = tomllib.load(f);
        }
        routes = doc.get("scale", {}).get("microservices", {}).get("routes", {});
        assert routes == {"cart_app": "/api/cart", "orders_app": "/orders"};
    }
}
