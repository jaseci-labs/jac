"""Tests for data-driven frozen sidecar plugin registration."""

import importlib.util;
import tempfile;
import from pathlib { Path }
import from _helpers { _SIDECAR_MAIN }


def _import_sidecar_main {
    spec = importlib.util.spec_from_file_location(
        "sidecar_main_plugins", _SIDECAR_MAIN
    );
    assert spec is not None and spec.loader is not None;
    module = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(module);
    return module;
}

test "load_sidecar_plugins_config reads plugins.desktop.plugins" {
    sidecar = _import_sidecar_main();
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir);
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n\n' + '[plugins.desktop.plugins]\n' + 'jac_scale = true\n' + 'byllm = false\n' + 'jac_mcp = false\n',
            encoding="utf-8"
        );
        cfg = sidecar.load_sidecar_plugins_config(project_dir);
        assert cfg.get("jac_scale") == True , "jac_scale should stay enabled";
        assert cfg.get("byllm") == False , "byllm should be disabled from jac.toml";
        assert cfg.get("jac_mcp") == False , "jac_mcp should be disabled from jac.toml";
        assert cfg.get("jac_coder") == True , "unspecified plugins should keep defaults";
    }
}

test "resolve_frozen_plugin_specs always includes jac_client core" {
    sidecar = _import_sidecar_main();
    specs = sidecar.resolve_frozen_plugin_specs(
        {"jac_scale": False, "byllm": False, "jac_coder": False, "jac_mcp": False}
    );
    core = [
        s
        for s in specs
        if s.module_path == "jac_client.plugin.client"
    ];
    assert len(core) == 1 , "jac_client should always be registered";
    assert core[0].entry_name == "serve" , "jac_client should use serve entry name";
}

test "resolve_frozen_plugin_specs honors disabled plugins" {
    sidecar = _import_sidecar_main();
    specs = sidecar.resolve_frozen_plugin_specs(
        {"jac_scale": True, "byllm": False, "jac_coder": False, "jac_mcp": False}
    );
    module_paths = {s.module_path for s in specs};
    assert "jac_scale.plugin" in module_paths , "enabled jac_scale should register";
    assert "byllm.plugin" not in module_paths , "disabled byllm should not register";
    assert "jac_mcp.plugin" not in module_paths , "disabled jac_mcp should not register";
}

test "resolve_frozen_plugin_specs uses entry point metadata when available" {
    sidecar = _import_sidecar_main();
    specs = sidecar.resolve_frozen_plugin_specs();
    module_paths = {s.module_path for s in specs};
    assert "jac_scale.plugin" in module_paths , "jac_scale should resolve";
    assert "byllm.plugin" in module_paths , "byllm should resolve";
    assert "jac_mcp.plugin" in module_paths , "jac_mcp should resolve";
}
