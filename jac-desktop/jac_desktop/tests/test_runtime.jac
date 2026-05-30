"""Unit tests for jac_desktop.runtime (PyTauri shell)."""

import importlib.util;
import types;
import from _helpers { _RUNTIME_PY }

"""Import runtime.py as a module."""
def _import_runtime -> types.ModuleType {
    spec = importlib.util.spec_from_file_location("jac_desktop_runtime", _RUNTIME_PY);
    if not spec or not spec.loader {
        raise ImportError("Could not load runtime.py module");
    }
    module = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(module);
    return module;
}

test "runtime defines sidecar port discovery" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "JAC_SIDECAR_PORT=" in content , (
        "Runtime should parse JAC_SIDECAR_PORT from sidecar stdout"
    );
    assert "JAC_SIDECAR_FAILED=" in content , (
        "Runtime should parse JAC_SIDECAR_FAILED from sidecar stdout"
    );
    assert "__JAC_SIDECAR_ERROR__" in content , (
        "Runtime should surface sidecar failures to the webview"
    );
    assert '"--port"' in content , "Runtime should pass --port to sidecar";
    assert '"0"' in content , "Runtime should use port 0 for dynamic allocation";
}

test "runtime injects api base url via initialization script" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "__JAC_API_BASE_URL__" in content , (
        "Runtime should set globalThis.__JAC_API_BASE_URL__"
    );
    assert "initialization_script" in content , (
        "Runtime should use initialization_script to inject URL before page JS"
    );
    assert "context_factory(shell_dir)" in content;
    assert "builder_factory().build(context" in content;
}

test "runtime loads tauri plugins from jac toml" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "get_tauri_plugins_config()" in content;
    assert "pytauri_plugins." in content;
}

test "runtime resolves api base url from env then toml" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "API_BASE_URL_ENV" in content;
    assert "os.environ.get(API_BASE_URL_ENV" in content;
    assert "_get_toml_api_base_url(project_dir)" in content;
}

test "runtime clears app windows in tauri config override" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert '"windows":[]' in content.replace(" ", "");
}

test "runtime sidecar boot timeout uses constant" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "thread.join(timeout=SIDECAR_BOOT_TIMEOUT)" in content , (
        "Sidecar port discovery should use SIDECAR_BOOT_TIMEOUT from desktop_helpers"
    );
    assert "30.0" not in content , "Runtime should not hardcode sidecar boot timeout";
    assert "within 30s" not in content , (
        "Sidecar timeout error messages should reference SIDECAR_BOOT_TIMEOUT"
    );
}
