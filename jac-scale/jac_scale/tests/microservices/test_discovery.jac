import tempfile;
import shutil;
import tomllib;
import from pathlib { Path }
import from jac_scale.runtime.discovery.discovery {
    discover_sv_services,
    should_enter_local_ms,
    scan_markers
}

glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent.parent / "fixtures" / "k8s_e2e";

test "discover on the k8s_e2e fixture matches its hand-written toml routes" {
    main = _K8S_E2E_FIXTURE / "main.jac";
    discovered = discover_sv_services(str(main));

    toml_path = _K8S_E2E_FIXTURE / "jac.toml";
    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }
    declared = (
        doc.get("plugins", {}).get("scale", {}).get("microservices", {}).get(
            "routes", {}
        )
    );

    assert discovered == dict(declared) , (
        f"auto-detect {discovered} != declared routes {dict(declared)}"
    );

    assert set(discovered.keys()) == {"products_app", "cart_app", "orders_app"};
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

test "scan_markers reads sv-import targets and the to-sv self-declaration" {
    m = scan_markers(
        "sv import from cart_app { view_cart }\nto sv:\ndef:pub f() -> int { return 1; }\n",
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
        "\"\"\"Docs: `sv import from cart_app { x }` and `to sv:` are mentioned.\"\"\"\nwith entry { print(1); }\n",
        "main.jac"
    );
    assert m is not None;
    assert m.sv_import_targets == [];
    assert m.is_service == False;
}

test "scan_markers: a plain import under a to-sv section is not an sv target" {
    m = scan_markers(
        "to sv:\nimport from helpers { h }\ndef:pub g() -> int { return 1; }\n",
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

test "discover finds to-sv files and sv-import targets" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\nimport from .frontend { app }\n");
    (Path(tmp) / "products_app.jac").write_text(
        "to sv:\ndef:pub list_products -> list { return []; }\n"
    );
    (Path(tmp) / "cart_app.jac").write_text(
        "to sv:\ndef:pub view_cart -> dict { return {}; }\n"
    );
    (Path(tmp) / "orders_app.jac").write_text(
        "sv import from cart_app { view_cart }\nto sv:\ndef:pub create_order -> dict { return {}; }\n"
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

    (Path(tmp) / "main.jac").write_text("to sv:\nsv import from worker_app { run }\n");
    (Path(tmp) / "worker_app.jac").write_text("to sv:\ndef:pub run -> None {}\n");

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert "main" not in routes;
    assert routes == {"worker_app": "/worker"};

    shutil.rmtree(tmp);
}

test "discover detects sv-import-only targets even without a local to-sv file" {
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
        "\"\"\"Docs: use `sv import from cart_app` to ...\nto sv: is also documented here.\n\"\"\"\nwith entry { print(1); }\n"
    );

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));
    assert routes == {};

    shutil.rmtree(tmp);
}

test "discover returns empty for a missing directory" {
    routes = discover_sv_services("/nonexistent/path/main.jac");
    assert routes == {};
}
