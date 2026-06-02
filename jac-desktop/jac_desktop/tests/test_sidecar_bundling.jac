"""Tests for sidecar bundling configuration (PyTauri / jac-desktop)."""

import from pathlib { Path }
import from _helpers { _DESKTOP_HELPERS_IMPL }

"""Verify default plugins config includes all expected plugins."""
test "desktop config has default plugins" {
    import jaclang;
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
    import tempfile;
    import os;

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            reset_desktop_config();
            with open("jac.toml", "w") as f {
                f.write(
                    '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                );
            }
            cfg = get_desktop_config(project_dir=Path(temp_dir));
            defaults = cfg.get_default_config();
            plugins = defaults.get("plugins", {});

            assert "jac_scale" in plugins , "jac_scale should be in default plugins";
            assert "byllm" in plugins , "byllm should be in default plugins";
            assert "jac_coder" in plugins , "jac_coder should be in default plugins";
            assert "jac_mcp" in plugins , "jac_mcp should be in default plugins";
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""jac_client is a core package, not a configurable plugin."""
test "desktop config jac_client not in configurable plugins" {
    import jaclang;
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
    import tempfile;
    import os;
    import from pathlib { Path }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            reset_desktop_config();
            with open("jac.toml", "w") as f {
                f.write(
                    '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                );
            }
            cfg = get_desktop_config(project_dir=Path(temp_dir));
            defaults = cfg.get_default_config();
            plugins = defaults.get("plugins", {});

            assert "jac_client" not in plugins , (
                "jac_client should NOT be in configurable plugins (it's always bundled as core)"
            );
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""client_only should default to False."""
test "desktop config client_only default is false" {
    import jaclang;
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
    import tempfile;
    import os;
    import from pathlib { Path }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            reset_desktop_config();
            with open("jac.toml", "w") as f {
                f.write(
                    '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                );
            }
            cfg = get_desktop_config(project_dir=Path(temp_dir));
            defaults = cfg.get_default_config();

            assert defaults.get("client_only", None) == False , (
                "client_only should default to False"
            );
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""Verify the spec file template excludes build artifact dirs from .jac collection."""
test "pyinstaller spec excludes build artifact dirs" {
    assert _DESKTOP_HELPERS_IMPL.exists();
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "src-pytauri" in content , "PyInstaller spec should reference src-pytauri exclusion";
    assert "node_modules" in content , "PyInstaller spec should reference node_modules exclusion";
}

"""Verify jac_client is in the core packages list for PyInstaller bundling."""
test "jac_client in core packages for collect_all" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "'jac_client'" in content , (
        "jac_client should be in the core packages list for collect_all"
    );
}
