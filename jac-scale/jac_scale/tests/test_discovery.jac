"""Tests for zero-config microservice discovery (discover_sv_services)."""

import tempfile;
import shutil;
import tomllib;
import from pathlib { Path }
import from jac_scale.microservices.discovery {
    discover_sv_services,
    should_enter_local_ms,
    _code_lines
}

glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e";

# =============================================================================
# Parity against the real example: auto-detection (ignoring the toml) must find
# exactly the services the fixture's [routes] table declares by hand. This is
# the regression guard that "zero-config == hand-written config" for a real app.
# =============================================================================
test "discover on the k8s_e2e fixture matches its hand-written toml routes" {
    main = _K8S_E2E_FIXTURE / "main.jac";
    discovered = discover_sv_services(str(main));

    toml_path = _K8S_E2E_FIXTURE / "jac.toml";
    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }
    declared = (
        doc.get("plugins", {})
        .get("scale", {})
        .get("microservices", {})
        .get("routes", {})
    );

    assert discovered == dict(declared) , (
        f"auto-detect {discovered} != declared routes {dict(declared)}"
    );
    # sanity: it actually found the three services
    assert set(discovered.keys()) == {"products_app", "cart_app", "orders_app"};
}

# =============================================================================
# should_enter_local_ms: tri-state gate
# =============================================================================
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
    # this_is_jac / plain single-file apps land here.
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

# =============================================================================
# _code_lines: comment + docstring stripping
# =============================================================================
test "_code_lines drops comments and blank lines" {
    text = "# a comment\n\n   \nto sv:\n";
    assert _code_lines(text) == ["to sv:"];
}

test "_code_lines drops multi-line docstrings (the false-positive guard)" {
    # The example apps embed `sv import from ...` inside their docstrings;
    # those must never be picked up as real statements.
    text = "\"\"\"Module doc.\n  - sv import: `sv import from cart_app { x }`\n\"\"\"\nto sv:\n";
    lines = _code_lines(text);
    assert lines == ["to sv:"];
}

test "_code_lines drops single-line docstrings" {
    text = "\"\"\"one liner with sv import from ghost\"\"\"\nsv import from real { f }\n";
    assert _code_lines(text) == ["sv import from real { f }"];
}

test "_code_lines: embedded triple-quote in body does not close docstring early" {
    # A docstring body line that *contains* the delimiter (e.g. documenting
    # triple-quotes) must not end the docstring; otherwise the lines after it
    # leak to the marker regexes as false-positive services. Only a line that
    # STARTS with the delimiter closes it.
    text = (
        "\"\"\"Module doc.\n"
        "Example body line shows a \"\"\" delimiter mid-text.\n"
        "sv import from ghost_app { f }\n"
        "\"\"\"\n"
        "sv import from real_app { g }\n"
    );
    assert _code_lines(text) == ["sv import from real_app { g }"];
}

test "_code_lines: code after a closing delimiter on the same line is kept" {
    # `""" to sv:` closes the docstring AND declares a service on one line;
    # the statement after the delimiter must not be silently dropped.
    text = "\"\"\"doc\n\"\"\" to sv:\n";
    assert _code_lines(text) == ["to sv:"];
}

# =============================================================================
# discover_sv_services: multi-service app
# =============================================================================
test "discover finds to-sv files and sv-import targets" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\nimport from .frontend { app }\n");
    (Path(tmp) / "products_app.jac").write_text("to sv:\ndef:pub list_products -> list { return []; }\n");
    (Path(tmp) / "cart_app.jac").write_text("to sv:\ndef:pub view_cart -> dict { return {}; }\n");
    (Path(tmp) / "orders_app.jac").write_text(
        "sv import from cart_app { view_cart }\nto sv:\ndef:pub create_order -> dict { return {}; }\n"
    );

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert routes == {
        "products_app": "/api/products",
        "cart_app": "/api/cart",
        "orders_app": "/api/orders"
    };

    shutil.rmtree(tmp);
}

test "discover excludes the entry module itself" {
    tmp = tempfile.mkdtemp();
    # Entry declares `to sv:` but is still the gateway host, not a peer.
    (Path(tmp) / "main.jac").write_text("to sv:\nsv import from worker_app { run }\n");
    (Path(tmp) / "worker_app.jac").write_text("to sv:\ndef:pub run -> None {}\n");

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert "main" not in routes;
    assert routes == {"worker_app": "/api/worker"};

    shutil.rmtree(tmp);
}

test "discover detects sv-import-only targets even without a local to-sv file" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("sv import from remote_app { f }\n");

    routes = discover_sv_services(str(Path(tmp) / "main.jac"));

    assert routes == {"remote_app": "/api/remote"};

    shutil.rmtree(tmp);
}

# =============================================================================
# discover_sv_services: monolith / regression
# =============================================================================
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
    # A monolith whose docstring mentions sv import must NOT be flagged.
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
