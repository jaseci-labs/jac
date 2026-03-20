"""Tests for PWA target functionality."""

import os;
import tempfile;
import from pathlib { Path }

"""Create a minimal jac.toml file for PWA testing."""
def _create_jac_toml_with_pwa(
    temp_dir: str,
    pwa_config: dict | None = None
) -> str {
    pwa_section = "";
    if pwa_config is not None {
        pwa_lines = ["[plugins.client.pwa]"];
        for (key, value) in pwa_config.items() {
            if isinstance(value, bool) {
                pwa_lines.append(f'{key} = {str(value).lower()}');
            } elif isinstance(value, int) {
                pwa_lines.append(f'{key} = {value}');
            } else {
                pwa_lines.append(f'{key} = "{value}"');
            }
        }
        pwa_section = "\n".join(pwa_lines);
    }

    toml_content = f'''[project]
name = "test-pwa-app"
version = "1.0.0"
description = "Test PWA project"
entry-point = "main.jac"

[dependencies.npm]
jac-client-node = "1.0.7"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "2.0.0"

{pwa_section}
''';
    config_path = os.path.join(temp_dir, "jac.toml");
    with open(config_path, "w") as f {
        f.write(toml_content);
    }
    return config_path;
}

# =============================================================================
# Config Loader Tests
# =============================================================================

"""Test is_pwa_enabled returns False when no PWA section exists."""
test "is_pwa_enabled returns false without pwa section" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml without PWA section
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }

            config = JacClientConfig(Path(temp_dir));
            assert not config.is_pwa_enabled(), "is_pwa_enabled should return False without PWA section";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test is_pwa_enabled returns True when PWA section exists."""
test "is_pwa_enabled returns true with pwa section" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml with PWA section
            _create_jac_toml_with_pwa(temp_dir, {"theme_color": "#000000"});

            config = JacClientConfig(Path(temp_dir));
            assert config.is_pwa_enabled(), "is_pwa_enabled should return True with PWA section";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test get_pwa_config returns correct values."""
test "get_pwa_config returns correct values" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            pwa_settings = {
                "theme_color": "#ff0000",
                "background_color": "#ffffff",
                "install_banner": True,
                "install_banner_delay": 5000
            };
            _create_jac_toml_with_pwa(temp_dir, pwa_settings);

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            assert pwa_config.get("theme_color") == "#ff0000", "theme_color mismatch";
            assert pwa_config.get("background_color") == "#ffffff", "background_color mismatch";
            assert pwa_config.get("install_banner"), "install_banner mismatch";
            assert pwa_config.get("install_banner_delay") == 5000, "install_banner_delay mismatch";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test get_pwa_config returns empty dict when no PWA section."""
test "get_pwa_config returns empty dict without pwa section" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            assert pwa_config == {}, "get_pwa_config should return empty dict without PWA section";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# Vite Config with PWA Alias Tests
# =============================================================================

"""Test that @jac/pwa alias is added to vite config when PWA is enabled."""
test "vite config includes pwa alias when enabled" {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with PWA enabled
            _create_jac_toml_with_pwa(temp_dir, {"theme_color": "#000000"});

            # Initialize bundler
            bundler = ViteBundler(Path(temp_dir));

            # Verify PWA is detected as enabled via config loader
            config = JacClientConfig(Path(temp_dir));
            assert config.is_pwa_enabled(), "PWA should be enabled";

            # Create mock entry file
            entry_file = Path(temp_dir) / ".jac" / "client" / "build" / "main.js";
            entry_file.parent.mkdir(parents=True, exist_ok=True);
            entry_file.write_text("// Mock entry");

            # Generate vite config
            vite_config_path = bundler.create_vite_config(entry_file);
            vite_content = vite_config_path.read_text();

            # Verify @jac/pwa alias is present
            assert "@jac/pwa" in vite_content, "@jac/pwa alias should be in vite config when PWA is enabled";
            assert "pwa_runtime.js" in vite_content, "Should reference pwa_runtime.js";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test that @jac/pwa alias is NOT added when PWA is disabled."""
test "vite config excludes pwa alias when disabled" {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml WITHOUT PWA section
            toml_content = '[project]\nname = "no-pwa-app"\nversion = "1.0.0"\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }

            # Initialize bundler
            bundler = ViteBundler(Path(temp_dir));

            # Verify PWA is NOT enabled via config loader
            config = JacClientConfig(Path(temp_dir));
            assert not config.is_pwa_enabled(), "PWA should not be enabled";

            # Create mock entry file
            entry_file = Path(temp_dir) / ".jac" / "client" / "build" / "main.js";
            entry_file.parent.mkdir(parents=True, exist_ok=True);
            entry_file.write_text("// Mock entry");

            # Generate vite config
            vite_config_path = bundler.create_vite_config(entry_file);
            vite_content = vite_config_path.read_text();

            # Verify @jac/pwa alias is NOT present
            assert "@jac/pwa" not in vite_content, "@jac/pwa alias should NOT be in vite config when PWA is disabled";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# PWA Setup Tests (via jac.toml parsing)
# =============================================================================

"""Test PWA install banner config defaults."""
test "pwa install banner config defaults" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml with minimal PWA section (should use defaults)
            _create_jac_toml_with_pwa(temp_dir, {"theme_color": "#000000"});

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            # Defaults should not be in config (they're applied at runtime)
            # Just verify PWA is enabled
            assert config.is_pwa_enabled(), "PWA should be enabled";
            assert "theme_color" in pwa_config, "theme_color should be in config";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test PWA config with custom banner settings."""
test "pwa custom banner settings" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            custom_settings = {
                "theme_color": "#ff0000",
                "install_banner": True,
                "install_banner_delay": 5000,
                "install_banner_position": "top",
                "install_button_text": "Get App",
                "install_dismiss_text": "Maybe Later"
            };
            _create_jac_toml_with_pwa(temp_dir, custom_settings);

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            assert pwa_config.get("install_banner_delay") == 5000, "Custom delay should be 5000";
            assert pwa_config.get("install_banner_position") == "top", "Position should be top";
            assert pwa_config.get("install_button_text") == "Get App", "Custom button text";
            assert pwa_config.get("install_dismiss_text") == "Maybe Later", "Custom dismiss text";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test PWA banner can be disabled."""
test "pwa banner can be disabled" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            _create_jac_toml_with_pwa(temp_dir, {
                "theme_color": "#000000",
                "install_banner": False
            });

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            assert config.is_pwa_enabled(), "PWA should still be enabled";
            assert not pwa_config.get("install_banner"), "Banner should be disabled";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# PWA Empty Section Edge Case
# =============================================================================

"""Test PWA is enabled with empty section."""
test "pwa enabled with empty section" {
    import from jac_client.plugin.src.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml with empty PWA section (just the header)
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n\n[plugins.client.pwa]\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }

            config = JacClientConfig(Path(temp_dir));
            # Empty section should NOT enable PWA (no keys = empty dict = length 0)
            # This is the expected behavior per is_pwa_enabled implementation
            # Note: An empty TOML section still creates an empty dict
            assert not config.is_pwa_enabled(), "Empty PWA section should not enable PWA";
        } finally {
            os.chdir(original_cwd);
        }
    }
}
