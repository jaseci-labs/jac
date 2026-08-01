"""Regression tests for direct client target registration.

The secondary `jac_client` pluggy plugin group is gone: targets ship with core
and register directly via `register_targets()` instead of being collected through
a `get_client_targets` hook. These tests pin that direct-registration contract.
"""

import from pathlib { Path }

glob _client_dir = Path(__file__).parent.parent.parent.parent
         / "jaclang"
         / "runtimelib"
         / "client",
     _register_jac = _client_dir / "targets" / "register.jac",
     _registry_jac = _client_dir / "targets" / "registry.jac",
     _cli_jac = _client_dir / "cli.jac";

test "register_targets registers the built-in client targets directly" {
    import from jaclang.runtimelib.client.targets.register { register_targets }
    import from jaclang.runtimelib.client.targets.registry { get_target_registry }

    register_targets();
    registry = get_target_registry();
    for name in ["web", "pwa", "static", "mobile", "desktop", "react-native"] {
        assert registry.get(name) is not None , (
            f"register_targets() must register the '{name}' target directly"
        );
    }
}

test "register.jac registers built-in targets without a plugin group" {
    content = _register_jac.read_text().replace("\r\n", "\n");
    # Direct registration: each built-in target is registered on the registry.
    assert "def register_targets" in content;
    assert "registry.register(WebTarget())" in content;
    assert "registry.register(MobileTarget())" in content;
    assert "registry.register(NativeDesktopTarget())" in content;
    assert "registry.register(ReactNativeTarget())" in content;
    assert "def sync_client_target_choices" in content;
    # The removed secondary plugin-group indirection must not have returned.
    assert "JacClientRuntime" not in content;
    assert "load_client_plugins" not in content;
    assert "get_client_targets" not in content;
    assert "with entry" not in content;
}

test "targets register lazily before sync reads them" {
    # Registration was folded into first registry access (lazy init): the CLI
    # no longer calls register_targets() eagerly. get_target_registry() self-
    # registers on first access, so any reader -- including the CLI's import-
    # time sync_client_target_choices() -- sees the built-in targets.
    cli_content = _cli_jac.read_text().replace("\r\n", "\n");
    # The CLI still triggers the import-time sync that wires target choices.
    assert "sync_client_target_choices();" in cli_content;
    assert "with entry {" in cli_content;
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
