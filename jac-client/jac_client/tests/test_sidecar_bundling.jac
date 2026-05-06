"""Tests for sidecar bundling configuration."""

import os;
import sys;
import from pathlib { Path }


test "desktop config has default plugins" {
    """Verify default plugins config includes all expected plugins."""
    import jaclang;
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    config = DesktopConfig();
    defaults = config.get_default_config();
    plugins = defaults.get("plugins", {});

    assert "jac_scale" in plugins, "jac_scale should be in default plugins";
    assert "byllm" in plugins, "byllm should be in default plugins";
    assert "jac_coder" in plugins, "jac_coder should be in default plugins";
    assert "jac_mcp" in plugins, "jac_mcp should be in default plugins";
}


test "desktop config jac_client not in configurable plugins" {
    """jac_client is a core package, not a configurable plugin."""
    import jaclang;
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    config = DesktopConfig();
    defaults = config.get_default_config();
    plugins = defaults.get("plugins", {});

    assert "jac_client" not in plugins,
        "jac_client should NOT be in configurable plugins (it's always bundled as core)";
}


test "desktop config client_only default is false" {
    """client_only should default to False."""
    import jaclang;
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    config = DesktopConfig();
    defaults = config.get_default_config();

    assert defaults.get("client_only", None) == False,
        "client_only should default to False";
}


test "pyinstaller spec excludes build artifact dirs" {
    """Verify the spec file template excludes src-tauri, node_modules etc from .jac collection."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        # Check that .jac collection excludes build artifacts
        assert "src-tauri" in content,
            "PyInstaller spec should reference src-tauri exclusion";
        assert "node_modules" in content,
            "PyInstaller spec should reference node_modules exclusion";
    }
}


test "jac_client in core packages for collect_all" {
    """Verify jac_client is in the core packages list for PyInstaller bundling."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "'jac_client'" in content,
            "jac_client should be in the core packages list for collect_all";
    }
}
