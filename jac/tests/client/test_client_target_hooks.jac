"""Regression tests for direct client target registration.

The secondary `jac_client` pluggy plugin group is gone: targets ship with core
and register directly via `register_targets()` instead of being collected through
a `get_client_targets` hook. These tests pin that direct-registration contract.
"""

import from pathlib { Path }

glob _client_dir = Path(__file__).parent.parent.parent / "jaclang" / "client",
     _register_jac = _client_dir / "targets" / "register.jac",
     _registry_jac = _client_dir / "targets" / "registry.jac",
     _cli_jac = _client_dir / "cli.jac";

test "register_targets registers the built-in client targets directly" {
    import from jaclang.client.targets.register { register_targets }
    import from jaclang.client.targets.registry { get_target_registry }

    register_targets();
    registry = get_target_registry();
    for name in ["web", "static", "desktop", "mobile"] {
        assert registry.get(name) is not None , (
            f"register_targets() must register the '{name}' target directly"
        );
    }
    # One target per client kind, and nothing else: PWA is a decoration of
    # the web build ([client.pwa]), CEF is a desktop engine ([desktop]
    # engine = "cef"), and the Capacitor / react-native names are gone.
    assert sorted(t.name for t in registry.get_all())
        == ["desktop", "mobile", "static", "web"] , (
        f"unexpected target set: {[t.name for t in registry.get_all()]}"
    );
    for gone in ["pwa", "cef", "react-native", "react_native", "native-desktop"] {
        assert registry.get(gone) is None , (
            f"'{gone}' is not a client target any more"
        );
    }
}

test "every client kind maps onto a registered target" {
    import from jaclang.client.targets.registry {
        KIND_TARGET,
        get_target_registry,
        target_for_kind
    }
    import from jaclang.project.kinds { KIND_SPECS, kind_has_client }
    import from pathlib { Path }

    registry = get_target_registry();
    assert KIND_TARGET
        == {
            "web-app": "web",
            "js-package": "web",
            "web-static": "static",
            "desktop": "desktop",
            "mobile": "mobile"
        };
    for (kind, spec) in KIND_SPECS.items() {
        if kind_has_client(kind) {
            assert kind in KIND_TARGET , f"client kind {kind} has no target";
            target = target_for_kind(kind, Path("."));
            assert target is registry.get(KIND_TARGET[kind]);
            assert spec.ui in ("dom", "mobui");
        } else {
            assert kind not in KIND_TARGET , f"{kind} has no client but a target";
            assert spec.ui == "";
        }
    }
}

test "register.jac registers built-in targets without a plugin group" {
    content = _register_jac.read_text().replace("\r\n", "\n");
    # Direct registration: each built-in target is registered on the registry.
    assert "def register_targets" in content;
    assert "registry.register(WebTarget())" in content;
    assert "registry.register(StaticTarget())" in content;
    assert "registry.register(DesktopTarget())" in content;
    assert "registry.register(MobileTarget())" in content;
    assert content.count("registry.register(") == 4 , (
        "exactly four targets: web, static, desktop, mobile"
    );
    for gone in [
        "PWATarget",
        "CefDesktopTarget",
        "NativeDesktopTarget",
        "ReactNativeTarget"
    ] {
        assert gone not in content , f"{gone} was folded away and must not be registered";
    }
    # The removed secondary plugin-group indirection must not have returned.
    assert "JacClientRuntime" not in content;
    assert "load_client_plugins" not in content;
    assert "get_client_targets" not in content;
    assert "with entry" not in content;
}

test "targets register lazily on first registry access" {
    # Registration was folded into first registry access (lazy init): the CLI
    # no longer calls register_targets() eagerly, and with the `--client`
    # flag gone (the kind picks the target) nothing at import time needs to
    # read the registry either.
    cli_content = _cli_jac.read_text().replace("\r\n", "\n");
    assert "sync_client_target_choices" not in cli_content;
    assert "--client" not in cli_content , "the --client flag is gone from the client CLI";
    assert "get_target_factory" not in cli_content , "targets resolve by kind now";
    assert "target_for_app" in cli_content;
    assert "with entry {" not in cli_content;
    # The eager register_targets() call must not have returned to cli.jac.
    assert "register_targets();" not in cli_content;

    registry_content = _registry_jac.read_text().replace("\r\n", "\n");
    # Lazy self-registration: register_targets() runs on first access, before
    # the registry is handed back to any caller (so before sync reads it).
    assert "register_targets();" in registry_content;
    reg_idx = registry_content.index("register_targets();");
    ret_idx = registry_content.index("return _registry;");
    assert reg_idx < ret_idx , "register_targets must run before get_target_registry returns";
}

"""`ensure_ready` is the universal readiness verb: the base ClientTarget consults
`requires_setup` and, when it is set, provisions through the target's own
`setup()`; otherwise it is a no-op. That is what finally gives the flag a
runtime meaning."""
test "ensure_ready on the base target consults requires_setup" {
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.registry { get_target_registry }

    registry = get_target_registry();
    target = registry.get("web");
    assert target is not None;
    assert target.requires_setup == False;
    calls: list[str] = [];

    def _fake_setup(project_dir: Path) {
        calls.append(f"setup:{project_dir}");
    }

    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(tmp);
        with unittest.mock.patch.object(target, "setup", _fake_setup) {
            target.ensure_ready(proj);
            assert calls == [] , "requires_setup = False: ensure_ready is a no-op";
            target.requires_setup = True;
            try {
                target.ensure_ready(proj);
                target.ensure_ready(proj);
            } finally {
                target.requires_setup = False;
            }
            assert calls == [f"setup:{proj}", f"setup:{proj}"] , (
                "requires_setup = True: the base ensure_ready provisions via setup()"
            );
        }
    }
}

"""Web, static and desktop provision inline (Vite, the webview host); none of
them needs a setup step, so `ensure_ready` must never call `setup()` on them."""
test "web, static and desktop ensure_ready are no-ops" {
    import tempfile;
    import unittest.mock;
    import from jaclang.client.targets.registry { get_target_registry }

    registry = get_target_registry();
    with tempfile.TemporaryDirectory() as tmp {
        proj = Path(tmp);
        for name in ["web", "static", "desktop"] {
            target = registry.get(name);
            assert target is not None , name;
            assert target.requires_setup == False , f"{name} needs no setup step";
            calls: list[str] = [];

            def _fake_setup(project_dir: Path) {
                calls.append(name);
            }
            with unittest.mock.patch.object(target, "setup", _fake_setup) {
                target.ensure_ready(proj);
            }
            assert calls == [] , f"{name}.ensure_ready must not provision: {calls}";
        }
    }
}

"""The CLI dispatcher (`run_client_build` / `run_client_start` in client/cli.jac)
asks every target for readiness before dispatching build, dev or start, so any
target that flips `requires_setup` gets lazy provisioning without further
wiring. The explicit `jac setup` path stays on `target.setup(...)`."""
test "the client dispatcher calls ensure_ready before build, dev and start" {
    content = _cli_jac.read_text().replace("\r\n", "\n");
    build_section = content.split("def run_client_build(")[1].split(
        "def run_client_start("
    )[0];
    start_section = content.split("def run_client_start(")[1].split("def get_config")[
        0
    ];
    for (label, section, dispatch) in [
        ("build", build_section, "target.build("),
        ("start", start_section, "target.dev("),
        ("start", start_section, "target.start(")
    ] {
        ready_idx = section.find("target.ensure_ready(project_dir");
        dispatch_idx = section.find(dispatch);
        assert ready_idx >= 0 , f"run_client_{label} must call target.ensure_ready";
        assert dispatch_idx >= 0 , f"run_client_{label} must call {dispatch}";
        assert ready_idx < dispatch_idx , (
            f"run_client_{label}: ensure_ready must run before {dispatch}"
        );
    }
    setup_section = content.split("def run_client_setup(")[1].split(
        "def _place_bundle("
    )[0];
    assert "target_obj.setup(project_dir)" in setup_section , (
        "jac setup stays the explicit pre-provision entry"
    );
    assert "ensure_ready" not in setup_section , (
        "jac setup calls setup() directly, not the lazy path"
    );
}
