"""Regression tests for plugin-provided client target registration."""

import from pathlib { Path }

glob _plugin_dir = Path(__file__).parent.parent / "plugin",
     _register_jac = _plugin_dir / "src" / "targets" / "register.jac",
     _cli_jac = _plugin_dir / "cli.jac";

test "register.jac collects plugin targets via get_client_targets hook" {
    content = _register_jac.read_text().replace("\r\n", "\n");
    assert "JacClientRuntime.get_client_targets()" in content;
    assert "load_client_plugins()" in content;
    assert "_register_plugin_client_targets" in content;
    assert "sync_client_target_choices" in content;
    assert "with entry" not in content;
}

test "client_plugin.jac defines JacClientPluginSpec and jac_client manager" {
    plugin_jac = _plugin_dir / "client_plugin.jac";
    content = plugin_jac.read_text().replace("\r\n", "\n");
    assert "class JacClientPluginSpec" in content;
    assert "client_plugin_manager" in content;
    assert "JacClientRuntime" in content;
    assert "load_setuptools_entrypoints('jac_client')" in content;
    assert "list[ClientTarget] | ClientTarget | None" in content;
}

test "cli create_cmd registers targets before syncing choices" {
    content = _cli_jac.read_text().replace("\r\n", "\n");
    assert "register_targets();" in content;
    assert "sync_client_target_choices();" in content;
    reg_idx = content.index("register_targets();");
    sync_idx = content.index("sync_client_target_choices();");
    assert reg_idx < sync_idx , "register_targets must run before sync_client_target_choices";
    assert "with entry {\n    register_targets();" not in content;
}
