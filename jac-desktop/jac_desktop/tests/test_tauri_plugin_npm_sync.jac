"""Tests for Tauri plugin npm auto-sync ([plugins.desktop].tauri_plugins)."""

import os;
import tempfile;
import from pathlib { Path }

"""Minimal jac.toml with client npm deps and [plugins.desktop].tauri_plugins."""
def _write_minimal_client_jac(
    temp_dir: str,
    tauri_plugins_line: str = 'tauri_plugins = ["dialog"]',
    auto_npm_line: str = ""
) {
    extra = "";
    if auto_npm_line {
        extra = auto_npm_line + "\n";
    }
    toml = f'''[project]
name = "sync-test-app"
version = "1.0.0"
description = "Test"
entry-point = "main.jac"

[dependencies.npm]
react = "^18.2.0"
react-dom = "^18.2.0"
react-router-dom = "^6.22.0"
react-error-boundary = "^5.0.0"

[dependencies.npm.dev]
vite = "^6.4.1"
"@vitejs/plugin-react" = "^4.2.1"
typescript = "^5.3.3"
"@types/react" = "^18.2.0"
"@types/react-dom" = "^18.2.0"

[plugins.desktop]
name = "Sync Test"
identifier = "com.example.sync_test"
version = "1.0.0"
{extra}{tauri_plugins_line}
''';
    with open(os.path.join(temp_dir, "jac.toml"), "w") as f {
        f.write(toml);
    }
}

"""is_auto_tauri_plugin_npm_enabled defaults true when key omitted."""
test "is_auto_tauri_plugin_npm_enabled defaults true when key omitted" {
    import jaclang;
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            reset_desktop_config();
            _write_minimal_client_jac(temp_dir, 'tauri_plugins = ["dialog"]');
            cfg = get_desktop_config(project_dir=Path(temp_dir));
            assert cfg.is_auto_tauri_plugin_npm_enabled() == True;
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""PyTauri impl wires sync through JacDesktopConfig for plugin/npm reconciliation."""
test "pytauri impl contains npm sync helpers" {
    impl_path = (
        Path(__file__).parent.parent / "targets" / "impl" / "pytauri_desktop_target.impl.jac"
    );
    assert impl_path.exists();
    text = impl_path.read_text(encoding="utf-8");
    assert "def sync_tauri_plugin_npm_dependencies(project_dir: Path)" in text;
    assert "desktop_cfg.is_auto_tauri_plugin_npm_enabled()" in text;
    assert "desktop_cfg.get_tauri_plugins_config()" in text;
    assert "regenerate_client_npm_install(project_dir)" in text;
}

"""PyTauri lifecycle calls sync before bundle / dev server.

Setup is intentionally excluded: it scaffolds `src-pytauri/` once and is a
no-op on re-run, so plugin npm reconciliation lives in build/dev where
config edits actually need to take effect.
"""
test "pytauri build and dev invoke sync" {
    impl_path = (
        Path(__file__).parent.parent / "targets" / "impl" / "pytauri_desktop_target.impl.jac"
    );
    text = impl_path.read_text(encoding="utf-8");
    n = text.count("sync_tauri_plugin_npm_dependencies(project_dir)");
    assert n >= 2 , "build and dev should each call sync";
}

"""Resolve jac-client package root (monorepo checkout or installed namespace pkg).

`jac_client` is a namespace package: it has ``__path__`` but ``__file__`` is None.
In the monorepo, prefer the sibling ``jac-client/`` checkout so tests see branch
changes instead of the PyPI wheel pinned by ``uv run``.
"""
def _jac_client_root -> Path {
    monorepo_root = Path(str(__file__)).parent.parent.parent.parent / "jac-client" / "jac_client";
    if monorepo_root.is_dir() {
        return monorepo_root;
    }
    import jac_client;
    paths = list(getattr(jac_client, "__path__", []) or []);
    if not paths {
        raise RuntimeError("jac_client package root not found");
    }
    return Path(str(paths[0]));
}

"""plugin_config exposes regenerate_client_npm_install for bun install."""
test "plugin_config exposes regenerate_client_npm_install" {
    client_root = _jac_client_root();
    cfg_path = client_root / "plugin" / "plugin_config.jac";
    assert cfg_path.exists();
    text = cfg_path.read_text(encoding="utf-8");
    assert "def regenerate_client_npm_install(project_dir: Path)" in text;
    assert "def _regenerate_and_install(project_dir: Path)" in text;
}
