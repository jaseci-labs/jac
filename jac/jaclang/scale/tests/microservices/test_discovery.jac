import tempfile;
import shutil;
import tomllib;
import from pathlib { Path }
import from jaclang.scale.runtime.discovery.discovery {
    discover_sv_services,
    discover_sv_service_files,
    resolve_routes,
    resolve_service_files,
    should_enter_local_ms,
    scan_markers
}

glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent.parent / "fixtures" / "k8s_e2e";

test "discover on the k8s_e2e fixture derives public prefixes with no toml routes" {
    # The fixture declares no [scale.microservices.routes] table -
    # services and their public prefixes are auto-discovered from `sv import`.
    main = _K8S_E2E_FIXTURE / "main.jac";
    discovered = discover_sv_services(str(main));

    assert discovered == {
        "products_app": "/products",
        "orders_app": "/orders",
        "cart_app": "/cart"
    } , f"unexpected auto-discovered routes: {discovered}";

    # Belt-and-suspenders: the fixture really has no routes table to fall back on.
    toml_path = _K8S_E2E_FIXTURE / "jac.toml";
    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }
    declared = (
        doc.get("plugins", {}).get("scale", {}).get("microservices", {}).get(
            "routes", {}
        )
    );
    assert declared == {} , f"fixture should carry no explicit routes, got {declared}";
}

test "gate: explicit enabled=True always enters (config wins)" {
    assert should_enter_local_ms(True, False, False, False) == True;
    assert should_enter_local_ms(True, False, False, True) == True;
}

test "gate: explicit enabled=False never enters (opt-out honored)" {
    assert should_enter_local_ms(False, False, False, True) == False;
    assert should_enter_local_ms(False, False, False, False) == False;
}

test "gate: unset (None) auto-detects on discovered services" {
    assert should_enter_local_ms(None, False, False, True) == True;
}

test "gate: unset (None) stays monolith when nothing discovered" {
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

test "scan_markers reads sv-import targets and the sv-block self-declaration" {
    m = scan_markers(
        "sv import from cart_app { view_cart }\nsv {\ndef:pub f() -> int { return 1; }\n}\n",
        "orders_app.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == ["cart_app"];
    assert m.is_service == True;
}

test "scan_markers detects the `sv { ... }` block form as a service" {
    m = scan_markers("sv {\n  def:pub g() -> int { return 1; }\n}\n", "svc.jac");
    assert m is not None;
    assert m.is_service == True;
}

test "scan_markers ignores sv-import text living only in a docstring" {
    m = scan_markers(
        "\"\"\"Docs: `sv import from cart_app { x }` and `sv { }` are mentioned.\"\"\"\nwith entry { print(1); }\n",
        "main.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == [];
    assert m.is_service == False;
}

test "scan_markers: a plain import inside an sv block is not an sv target" {
    m = scan_markers(
        "sv {\nimport from helpers { h }\ndef:pub g() -> int { return 1; }\n}\n",
        "svc.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == [];
    assert m.is_service == True;
}

test "scan_markers returns multiple sv-import targets" {
    m = scan_markers(
        "sv import from cart_app { a }\nsv import from products_app { b }\n", "main.jac"
    );
    assert m is not None;
    assert sorted(m.sv_import_targets) == ["cart_app", "products_app"];
}

test "discover registers .sv.jac services under their logical module stem" {
    # base_stem applies to all variant suffixes (.sv/.cl/.na.jac), not only .sv.jac.
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("with entry { print(1); }\n");
    (Path(tmp) / "products_app.sv.jac").write_text(
        "sv {\ndef:pub list_products -> list { return []; }\n}\n"
    );

    try {
        routes = discover_sv_services(str(Path(tmp) / "main.jac"));

        assert routes == {"products_app": "/products"} , (
            f".sv.jac service must register as logical stem products_app, got: {routes}"
        );

        files = discover_sv_service_files(str(Path(tmp) / "main.jac"));
        assert files.get("products_app") == "products_app.sv.jac" , (
            f".sv.jac service file must map to products_app.sv.jac, got: {files}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover finds sv-block files and sv-import targets" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("cl {\nimport from .frontend { app }\n}\n");
    (Path(tmp) / "products_app.jac").write_text(
        "sv {\ndef:pub list_products -> list { return []; }\n}\n"
    );
    (Path(tmp) / "cart_app.jac").write_text(
        "sv {\ndef:pub view_cart -> dict { return {}; }\n}\n"
    );
    (Path(tmp) / "orders_app.jac").write_text(
        "sv import from cart_app { view_cart }\nsv {\ndef:pub create_order -> dict { return {}; }\n}\n"
    );

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert routes == {
        "products_app": "/products",
        "cart_app": "/cart",
        "orders_app": "/orders"
    };

    shutil.rmtree(tmp);
}

test "discover excludes the entry module itself" {
    tmp = tempfile.mkdtemp();

    (Path(tmp) / "main.jac").write_text("sv {\nsv import from worker_app { run }\n}\n");
    (Path(tmp) / "worker_app.jac").write_text("sv {\ndef:pub run -> None {}\n}\n");

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert "main" not in routes;
    assert routes == {"worker_app": "/worker"};

    shutil.rmtree(tmp);
}

test "discover excludes variant-suffix entry module from routes" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.sv.jac").write_text(
        "sv {\nsv import from worker_app { run }\n}\n"
    );
    (Path(tmp) / "worker_app.jac").write_text("sv {\ndef:pub run -> None {}\n}\n");

    try {
        routes = discover_sv_services(str(Path(tmp) / "main.sv.jac"));
        assert "main" not in routes , (
            f"entry stem must use base_stem so main.sv.jac is excluded, got: {routes}"
        );
        assert routes == {"worker_app": "/worker"};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover prefers matching codespace when stem paths collide" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from foo { bar }\n");
    (Path(tmp) / "foo.jac").write_text("def helper() -> int { return 1; }\n");
    (Path(tmp) / "foo.sv.jac").write_text("def:pub bar() -> int { return 2; }\n");

    try {
        files = discover_sv_service_files(str(Path(tmp) / "main.jac"));
        assert files.get("foo") == "foo.sv.jac" , (
            f"import-only target must prefer server codespace on stem collision, got: {files}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover prefers sv-block file when stem paths collide" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from foo { bar }\n");
    (Path(tmp) / "foo.jac").write_text("sv {\ndef:pub bar() -> int { return 1; }\n}\n");
    (Path(tmp) / "foo.sv.jac").write_text("def:pub other() -> int { return 2; }\n");

    try {
        files = discover_sv_service_files(str(Path(tmp) / "main.jac"));
        assert files.get("foo") == "foo.jac" , (
            f"sv-block owner must win stem collision over plain variant file, got: {files}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover prefers plain module over impl annex on stem collision" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from foo { bar }\n");
    (Path(tmp) / "foo.jac").write_text("def:pub bar() -> int { return 1; }\n");
    (Path(tmp) / "foo.impl.jac").write_text("def impl_helper() -> int { return 2; }\n");

    try {
        files = discover_sv_service_files(str(Path(tmp) / "main.jac"));
        assert files.get("foo") == "foo.jac" , (
            f"plain module must win stem collision over impl annex, got: {files}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover prefers server codespace when two service files collide" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from foo { bar }\n");
    (Path(tmp) / "foo.jac").write_text("sv {\ndef:pub bar() -> int { return 1; }\n}\n");
    (Path(tmp) / "foo.sv.jac").write_text(
        "sv {\ndef:pub bar() -> int { return 2; }\n}\n"
    );

    try {
        files = discover_sv_service_files(str(Path(tmp) / "main.jac"));
        assert files.get("foo") == "foo.sv.jac" , (
            f"server codespace must win when both files declare sv blocks, got: {files}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "discover detects sv-import-only targets even without a local sv-block file" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from remote_app { f }\n");

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert routes == {"remote_app": "/remote"};

    shutil.rmtree(tmp);
}

test "discover returns empty for a single-file monolith (regression guard)" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text(
        "\"\"\"A plain app.\"\"\"\nwith entry { print(\"hi\"); }\n"
    );

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));
    assert routes == {};

    shutil.rmtree(tmp);
}

test "discover ignores sv-import text that lives only in docstrings" {
    tmp = tempfile.mkdtemp();

    (Path(tmp) / "main.jac").write_text(
        "\"\"\"Docs: use `sv import from cart_app` to ...\nsv { } is also documented here.\n\"\"\"\nwith entry { print(1); }\n"
    );

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));
    assert routes == {};

    shutil.rmtree(tmp);
}

test "discover returns empty for a missing directory" {
    routes = discover_sv_services("/nonexistent/path/main.jac");
    assert routes == {};
}

test "discover finds a service living in a subdir of the same project" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    sub = tmp / "littlex";
    sub.mkdir();
    (sub / "social_graph.jac").write_text(
        "sv {\ndef:pub setup_profile -> int { return 1; }\n}\n"
    );
    try {
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert "social_graph" in routes , (
            f"same-project subdir service missing: {routes}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "discover treats a nested jac.toml as a separate-project boundary" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"parent\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");

    embedded = tmp / "embedded";
    embedded.mkdir();
    (embedded / "social_graph.jac").write_text(
        "sv {\ndef:pub setup_profile -> int { return 1; }\n}\n"
    );

    other = tmp / "other_app";
    other.mkdir();
    (other / "jac.toml").write_text("[project]\nname = \"other\"\n");
    (other / "orders_app.jac").write_text(
        "sv {\ndef:pub list_orders -> int { return 1; }\n}\n"
    );
    try {
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert "social_graph" in routes , (
            f"same-project embedded service missing: {routes}"
        );
        assert "orders_app" not in routes , (
            f"nested subproject leaked into discovery: {routes}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "discover prunes build/vendor dirs" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    vendored = tmp / "node_modules" / "pkg";
    vendored.mkdir(parents=True);
    (vendored / "ghost_app.jac").write_text(
        "sv {\ndef:pub run -> int { return 1; }\n}\n"
    );
    try {
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert "ghost_app" not in routes , (
            f"vendored service leaked into discovery: {routes}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "discover_sv_service_files maps a subdir service to its real relative path" {
    import os;
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    (tmp / "analytics.jac").write_text("sv {\ndef:pub stats -> int { return 1; }\n}\n");
    sub = tmp / "littlex";
    sub.mkdir();
    (sub / "social_graph.jac").write_text(
        "sv {\ndef:pub setup_profile -> int { return 1; }\n}\n"
    );
    try {
        files = discover_sv_service_files(str(tmp / "main.jac"));
        assert files.get("analytics") == "analytics.jac" , (
            f"root-level service path wrong: {files}"
        );
        assert files.get("social_graph") == os.path.join(
            "littlex", "social_graph.jac"
        ) , (f"subdir service must keep its relative path, got: {files}");
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "a subdir service discovered only via sv import resolves to its file" {
    import os;
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    sub = tmp / "littlex";
    sub.mkdir();
    (sub / "social_graph.jac").write_text(
        "def:pub setup_profile -> int { return 1; }\n"
    );
    (sub / "api.jac").write_text("sv import from .social_graph { setup_profile }\n");
    try {
        files = discover_sv_service_files(str(tmp / "main.jac"));
        assert files.get("social_graph") == os.path.join(
            "littlex", "social_graph.jac"
        ) , (
            f"an sv-import target with no `sv {{ }}` marker of its own must "
            f"still resolve to its real file, got: {files}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "scan_markers ignores sv imports in a .cl.jac client module" {
    m = scan_markers(
        "sv import from social_graph { setup_profile }\n", "frontend.cl.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == [];
}

test "scan_markers ignores sv imports inside a cl block" {
    m = scan_markers(
        "cl {\nsv import from social_graph { setup_profile }\n}\n", "main.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == [];
}

test "a client-only sv import does not trigger service discovery" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    (tmp / "util_svc.jac").write_text("def:pub helper -> int { return 1; }\n");
    pages = tmp / "pages";
    pages.mkdir();
    (pages / "Home.cl.jac").write_text(
        "sv import from ..util_svc { helper }\ndef:pub Home -> None {\n    helper();\n}\n"
    );
    try {
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert routes == {} , (
            f"client-side sv import must not flip on microservice mode, got: {routes}"
        );
        assert should_enter_local_ms(None, False, False, bool(routes)) == False;
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "a cl-block sv import does not trigger service discovery" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text(
        "cl {\nsv import from util_svc { helper }\n}\nwith entry { print(1); }\n"
    );
    (tmp / "util_svc.jac").write_text("def:pub helper -> int { return 1; }\n");
    try {
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert routes == {} , (
            f"cl-block sv import must not flip on microservice mode, got: {routes}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "a dotted sv-import target resolves to the service module stem" {
    # A server-side bridge that does not sit in the service's own directory
    # addresses it with a dotted target; discovery is keyed by module stem, so
    # the dotted form must be reduced or it registers a phantom service.
    import os;
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    svc = tmp / "services";
    svc.mkdir();
    (svc / "ideServer.jac").write_text("def:pub ping -> int { return 1; }\n");
    bridge = tmp / "apps";
    bridge.mkdir();
    (bridge / "bridge.jac").write_text("sv import from services.ideServer { ping }\n");
    try {
        files = discover_sv_service_files(str(tmp / "main.jac"));
        assert files.get("ideServer") == os.path.join("services", "ideServer.jac") , (
            "dotted sv-import target must resolve to the real service file, "
            f"got: {files}"
        );
        routes = discover_sv_services(str(tmp / "main.jac"));
        assert "services.ideServer" not in routes , (
            "the dotted form must not register a phantom service/route, "
            f"got: {routes}"
        );
        assert routes.get("ideServer") == "/ideServer" , (
            f"expected a clean /ideServer route, got: {routes}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "sv_target_stem reduces dotted, path and suffixed import targets" {
    import from jaclang.scale.runtime.discovery.discovery { sv_target_stem }

    assert sv_target_stem("ideServer") == "ideServer";
    assert sv_target_stem("services.ideServer") == "ideServer";
    assert sv_target_stem("a.b.c.deepSvc") == "deepSvc";
    # String-path targets must not degrade to the file extension.
    assert sv_target_stem("services/ideServer.jac") == "ideServer";
    assert sv_target_stem("./services/ideServer") == "ideServer";
    assert sv_target_stem("ideServer.sv.jac") == "ideServer";
}

test "resolve_service_files falls back to <name>.jac for import-only routes" {
    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("sv import from remote_app { f }\n");
    try {
        files = resolve_service_files(str(tmp / "main.jac"), {"remote_app": "/remote"});
        assert files == {"remote_app": "remote_app.jac"} , (
            f"import-only service must fall back to <name>.jac, got: {files}"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "resolve_routes merges discovered services with explicit routes" {
    main = _K8S_E2E_FIXTURE / "main.jac";

    explicit = {"products_app": "/custom-products", "extra": "/extra"};
    merged = resolve_routes(str(main), explicit);

    assert "cart_app" in merged and "orders_app" in merged , (
        f"discovered services dropped: {merged}"
    );

    assert merged["products_app"] == "/custom-products";

    assert merged["extra"] == "/extra";
}
