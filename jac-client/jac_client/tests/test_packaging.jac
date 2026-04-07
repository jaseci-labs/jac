"""Tests for jac_client package structure.

Verifies that __init__.py and __init__.jac files exist in the right
places for PyInstaller compatibility.
"""

import os;
import from pathlib { Path }


test "jac_client root has __init__.py" {
    import jac_client;
    root = Path(jac_client.__path__[0]);
    assert (root / "__init__.py").exists() or (root / "__init__.jac").exists(),
        f"jac_client root at {root} needs __init__.py or __init__.jac";
}


test "jac_client.plugin has __init__ files" {
    import jac_client;
    plugin_dir = Path(jac_client.__path__[0]) / "plugin";
    if plugin_dir.exists() {
        has_init = (plugin_dir / "__init__.py").exists() or (plugin_dir / "__init__.jac").exists();
        assert has_init,
            f"jac_client/plugin/ needs __init__.py or __init__.jac";
    }
}


test "jac_client.plugin.src has __init__ for exports" {
    """src/ has __init__.jac that exports ViteCompiler etc.
    It also needs __init__.py that re-exports for frozen apps."""
    import jac_client;
    src_dir = Path(jac_client.__path__[0]) / "plugin" / "src";
    if src_dir.exists() {
        has_jac = (src_dir / "__init__.jac").exists();
        has_py = (src_dir / "__init__.py").exists();
        assert has_jac or has_py,
            "plugin/src/ needs __init__.jac or __init__.py for exports";
    }
}


test "import jac_client.plugin.client succeeds" {
    """The critical import that failed in frozen apps."""
    import jaclang;  # registers meta-importer
    import importlib;
    mod = importlib.import_module("jac_client.plugin.client");
    assert hasattr(mod, "JacClient"),
        "jac_client.plugin.client should export JacClient";
}


test "ViteCompiler importable from src" {
    """ViteCompiler must be accessible — this is what broke in frozen sidecar."""
    import jaclang;
    import importlib;
    try {
        mod = importlib.import_module("jac_client.plugin.src");
        # May need .compiler submodule
        if not hasattr(mod, "ViteCompiler") {
            mod = importlib.import_module("jac_client.plugin.src.compiler");
        }
        assert hasattr(mod, "ViteCompiler"),
            "ViteCompiler not found in jac_client.plugin.src or .src.compiler";
    } except ImportError as e {
        assert False, f"Import failed: {e}";
    }
}
