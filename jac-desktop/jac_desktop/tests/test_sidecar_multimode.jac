"""Tests for multi-mode sidecar functionality."""

import importlib.util;
import inspect;
import from _helpers { _SIDECAR_MAIN }


def _import_sidecar_main(alias: str) {
    spec = importlib.util.spec_from_file_location(alias, _SIDECAR_MAIN);
    assert spec is not None and spec.loader is not None;
    module = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(module);
    return module;
}

"""Verify register_frozen_plugins is importable."""
test "register_frozen_plugins function exists" {
    module = _import_sidecar_main("sidecar_main1");
    assert hasattr(module, "register_frozen_plugins");
    assert callable(module.register_frozen_plugins);
}

"""Verify _run_jac_cli is importable."""
test "run_jac_cli function exists" {
    module = _import_sidecar_main("sidecar_main2");
    assert hasattr(module, "_run_jac_cli");
    assert callable(module._run_jac_cli);
}

"""Verify main() is importable."""
test "sidecar main function exists" {
    module = _import_sidecar_main("sidecar_main3");
    assert hasattr(module, "main");
    assert callable(module.main);
}

"""Verify sidecar main delegates frozen registration to frozen_plugins."""
test "sidecar main uses data driven frozen plugin registration" {
    content = _SIDECAR_MAIN.read_text(encoding="utf-8");
    assert "def register_frozen_plugins(" in content;
    assert "register_frozen_plugins(plugin_manager" in content;
}

"""Verify main.py loads .env from _MEIPASS."""
test "env loading from MEIPASS in main" {
    module = _import_sidecar_main("sidecar_main5");
    source = inspect.getsource(module.main);
    assert "_MEIPASS" in source , "main() should reference _MEIPASS for .env loading";
    assert "load_dotenv" in source or "dotenv" in source or ".env" in source , (
        "main() should load .env from bundled location"
    );
}
