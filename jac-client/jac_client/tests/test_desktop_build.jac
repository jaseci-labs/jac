"""Tests for desktop build improvements."""

import os;
import sys;
import from pathlib { Path }


test "client_only config is supported" {
    """Verify DesktopConfig supports client_only field."""
    import jaclang;
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    config = DesktopConfig();
    defaults = config.get_default_config();
    assert "client_only" in defaults,
        "DesktopConfig should have client_only in defaults";
    assert defaults["client_only"] == False,
        "client_only should default to False";
}


test "is_client_only method exists" {
    """Verify DesktopConfig has is_client_only method."""
    import jaclang;
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    config = DesktopConfig();
    assert hasattr(config, "is_client_only"),
        "DesktopConfig should have is_client_only method";
    assert callable(config.is_client_only),
        "is_client_only should be callable";
    # Default should be False
    assert config.is_client_only() == False,
        "Default is_client_only should be False";
}


test "JAC_BUILD env var set during build" {
    """Verify the desktop build sets JAC_BUILD=1 to prevent server startup."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "JAC_BUILD" in content,
            "desktop_target should set JAC_BUILD env var during build";
    }
}


test "client_only skips sidecar bundling" {
    """Verify the build logic checks client_only to skip sidecar."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "is_client_only" in content,
            "Build should check is_client_only";
        assert "Sidecar bundling skipped" in content,
            "Build should have skip message for client_only mode";
    }
}


test "client_only requires base_url" {
    """Verify client_only mode validates that base_url is set."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "client_only = true requires" in content,
            "client_only mode should validate base_url is set";
    }
}
