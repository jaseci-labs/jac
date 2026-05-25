"""Regression: desktop target registers via JacDesktopPlugin + get_client_targets."""

import from pathlib { Path }

glob _plugin_jac = Path(__file__).parent.parent / "plugin.jac",
     _plugin_impl = Path(__file__).parent.parent / "impl" / "plugin.impl.jac",
     _cli_jac = Path(__file__).parent.parent / "cli.jac";

test "plugin.jac implements JacClientPluginSpec get_client_targets hook" {
    content = _plugin_jac.read_text().replace("\r\n", "\n");
    assert "class JacDesktopPlugin" in content;
    assert "@client_hookimpl\n    static def get_client_targets" in content;
    assert "list[ClientTarget] | ClientTarget" in content;
    assert "client_hookimpl" in content;
    assert "plugin_manager.register" not in content;
    assert "extend_client_choices" not in content;
    assert "register_desktop_target" not in content;
}

test "plugin impl returns PyTauriDesktopTarget from hook" {
    content = _plugin_impl.read_text().replace("\r\n", "\n");
    assert "impl JacDesktopPlugin.get_client_targets" in content;
    assert "PyTauriDesktopTarget()" in content;
}

test "cli plugin add remove share apply helper" {
    content = _cli_jac.read_text().replace("\r\n", "\n");
    assert "def _apply_plugin_diff(" in content;
    assert "_handle_plugin_add" in content;
    assert "_handle_plugin_remove" in content;
    assert "_apply_plugin_diff(ctx, project_dir, PluginAction.ADD)" in content;
    assert "_apply_plugin_diff(ctx, project_dir, PluginAction.REMOVE)" in content;
}

test "cli.jac defines JacCmd for jac desktop subcommand" {
    content = _cli_jac.read_text().replace("\r\n", "\n");
    assert "class JacCmd" in content;
    assert "create_cmd" in content;
}
