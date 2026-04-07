"""Tests for desktop target build configuration."""

import os;
import sys;
import from pathlib { Path }


test "desktop_target has increased timeout" {
    """Verify SUBPROCESS_TIMEOUT_BUILD is at least 3600s."""
    import from pathlib { Path }
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "SUBPROCESS_TIMEOUT_BUILD" in content;
        # Check timeout is >= 3600
        for line in content.split("\n") {
            if "SUBPROCESS_TIMEOUT_BUILD" in line and "int" in line and "=" in line {
                # Extract value
                parts = line.split("=");
                if len(parts) >= 2 {
                    try {
                        val = int(parts[-1].strip().rstrip(",;"));
                        assert val >= 3600,
                            f"SUBPROCESS_TIMEOUT_BUILD should be >= 3600, got {val}";
                    } except ValueError { }
                }
            }
        }
    }
}


test "desktop_target bundles assets directory" {
    """Verify PyInstaller spec auto-bundles assets/ directory."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "assets" in content and "assets_dir" in content,
            "desktop_target should auto-bundle assets/ directory";
    }
}


test "desktop_target bundles env file" {
    """Verify PyInstaller spec auto-bundles .env file."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "env_file" in content or ".env" in content,
            "desktop_target should auto-bundle .env file";
    }
}


test "desktop_target shows pyinstaller logs" {
    """Verify capture_output=False for PyInstaller build visibility."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "capture_output=False" in content,
            "PyInstaller should run with capture_output=False for log visibility";
    }
}


test "desktop_target includes jac_client in collect_all" {
    """Verify jac_client is in the core packages list."""
    target_file = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";
    if target_file.exists() {
        with open(str(target_file), "r", encoding="utf-8") as f {
            content = f.read();
        }
        assert "'jac_client'" in content,
            "jac_client should be in the core packages for collect_all";
    }
}
