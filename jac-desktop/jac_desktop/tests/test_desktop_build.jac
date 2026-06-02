"""Tests for PyTauri desktop build improvements."""

import from pathlib { Path }
import from _helpers { _PYTAURI_TARGET_IMPL }

"""Verify JacDesktopConfig supports client_only field."""
test "client_only config is supported" {
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
            assert "client_only" in defaults , "JacDesktopConfig should have client_only in defaults";
            assert defaults["client_only"] == False , "client_only should default to False";
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""Verify JacDesktopConfig has is_client_only method."""
test "is_client_only method exists" {
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
            assert hasattr(cfg, "is_client_only") , "JacDesktopConfig should have is_client_only method";
            assert callable(cfg.is_client_only) , "is_client_only should be callable";
            assert cfg.is_client_only() == False , "Default is_client_only should be False";
        } finally {
            reset_desktop_config();
            os.chdir(original_cwd);
        }
    }
}

"""Verify the PyTauri desktop build sets JAC_BUILD=1 to prevent server startup."""
test "JAC_BUILD env var set during build" {
    assert _PYTAURI_TARGET_IMPL.exists();
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert "JAC_BUILD" in content , "PyTauri build should set JAC_BUILD env var during web bundle build";
}

"""Verify the build logic checks client_only to skip sidecar."""
test "client_only skips sidecar bundling" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert "is_client_only" in content , "Build should check is_client_only";
    assert "Sidecar bundling skipped" in content , "Build should have skip message for client_only mode";
}

"""Verify client_only mode validates that base_url is set."""
test "client_only requires base_url" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert "client_only mode requires" in content , (
        "client_only mode should validate base_url is set"
    );
}
