"""Regression tests for direct client target registration.

The secondary `jac_client` pluggy plugin group is gone: targets ship with core
and register directly via `register_targets()` instead of being collected through
a `get_client_targets` hook. These tests pin that direct-registration contract.
"""

import from pathlib { Path }

glob _client_dir = Path(__file__).parent.parent.parent.parent / "jaclang" / "runtimelib" / "client",
     _register_jac = _client_dir / "targets" / "register.jac",
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

test "cli registers targets before syncing choices at import" {
    content = _cli_jac.read_text().replace("\r\n", "\n");
    assert "register_targets();" in content;
    assert "sync_client_target_choices();" in content;
    reg_idx = content.index("register_targets();");
    sync_idx = content.index("sync_client_target_choices();");
    assert reg_idx < sync_idx , "register_targets must run before sync_client_target_choices";
    # Registration now happens at module import (with entry), since the CLI
    # imports this module at startup; there is no create_cmd hook anymore.
    assert "with entry {" in content;
}
