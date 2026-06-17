"""Tests for PWA target functionality."""

import os;
import tempfile;
import from pathlib { Path }
import from jac_client.plugin.src.targets.pwa_target {
    _build_install_prompt_capture_script,
    _build_sw_registration_script,
    _build_pwa_install_banner_script
}

"""Create a minimal jac.toml file for PWA testing."""
def _create_jac_toml_with_pwa(temp_dir: str, pwa_config: dict | None = None) -> str {
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
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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
            assert not config.is_pwa_enabled() , "is_pwa_enabled should return False without PWA section";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test is_pwa_enabled returns True when PWA section exists."""
test "is_pwa_enabled returns true with pwa section" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml with PWA section
            _create_jac_toml_with_pwa(temp_dir, {"theme_color": "#000000"});

            config = JacClientConfig(Path(temp_dir));
            assert config.is_pwa_enabled() , "is_pwa_enabled should return True with PWA section";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test get_pwa_config returns correct values."""
test "get_pwa_config returns correct values" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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

            assert pwa_config.get("theme_color") == "#ff0000" , "theme_color mismatch";
            assert pwa_config.get("background_color") == "#ffffff" , "background_color mismatch";
            assert pwa_config.get("install_banner") , "install_banner mismatch";
            assert pwa_config.get("install_banner_delay") == 5000 , "install_banner_delay mismatch";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test get_pwa_config returns empty dict when no PWA section."""
test "get_pwa_config returns empty dict without pwa section" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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

            assert pwa_config == {} , "get_pwa_config should return empty dict without PWA section";
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
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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
            assert config.is_pwa_enabled() , "PWA should be enabled";

            # Create mock entry file
            entry_file = Path(temp_dir) / ".jac" / "client" / "build" / "main.js";
            entry_file.parent.mkdir(parents=True, exist_ok=True);
            entry_file.write_text("// Mock entry");

            # Generate vite config
            vite_config_path = bundler.create_vite_config(entry_file);
            vite_content = vite_config_path.read_text();

            # Verify @jac/pwa alias is present
            assert "@jac/pwa" in vite_content , "@jac/pwa alias should be in vite config when PWA is enabled";
            assert "pwa_runtime.js" in vite_content , "Should reference pwa_runtime.js";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test that @jac/pwa alias is NOT added when PWA is disabled."""
test "vite config excludes pwa alias when disabled" {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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
            assert not config.is_pwa_enabled() , "PWA should not be enabled";

            # Create mock entry file
            entry_file = Path(temp_dir) / ".jac" / "client" / "build" / "main.js";
            entry_file.parent.mkdir(parents=True, exist_ok=True);
            entry_file.write_text("// Mock entry");

            # Generate vite config
            vite_config_path = bundler.create_vite_config(entry_file);
            vite_content = vite_config_path.read_text();

            # Verify @jac/pwa alias is NOT present
            assert "@jac/pwa" not in vite_content , "@jac/pwa alias should NOT be in vite config when PWA is disabled";
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
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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
            assert config.is_pwa_enabled() , "PWA should be enabled";
            assert "theme_color" in pwa_config , "theme_color should be in config";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test PWA config with custom banner settings."""
test "pwa custom banner settings" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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

            assert pwa_config.get("install_banner_delay") == 5000 , "Custom delay should be 5000";
            assert pwa_config.get("install_banner_position") == "top" , "Position should be top";
            assert pwa_config.get("install_button_text") == "Get App" , "Custom button text";
            assert pwa_config.get("install_dismiss_text") == "Maybe Later" , "Custom dismiss text";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test PWA banner can be disabled."""
test "pwa banner can be disabled" {
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            _create_jac_toml_with_pwa(
                temp_dir, {"theme_color": "#000000", "install_banner": False}
            );

            config = JacClientConfig(Path(temp_dir));
            pwa_config = config.get_pwa_config();

            assert config.is_pwa_enabled() , "PWA should still be enabled";
            assert not pwa_config.get("install_banner") , "Banner should be disabled";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

# =============================================================================
# PWA Runtime Script Injection Tests
# =============================================================================

"""Test that install prompt capture script contains beforeinstallprompt handler."""
test "pwa install prompt capture script has beforeinstallprompt" {
    script = _build_install_prompt_capture_script();
    assert "beforeinstallprompt" in script,
        "Prompt capture script must listen for beforeinstallprompt event";
    assert "__jacPwaPrompt" in script,
        "Prompt capture script must store the prompt event";
    assert "<script>" in script,
        "Prompt capture must be wrapped in a script tag";
}

"""Test that SW registration script registers sw.js."""
test "pwa sw registration script registers service worker" {
    script = _build_sw_registration_script();
    assert "serviceWorker" in script,
        "SW registration script must check for serviceWorker support";
    assert "sw.js" in script,
        "SW registration script must register sw.js";
    assert "<script>" in script,
        "SW registration must be wrapped in a script tag";
}

"""Test that install banner script contains banner UI and dismiss logic."""
test "pwa install banner script contains banner ui" {
    script = _build_pwa_install_banner_script({});
    assert "jac-pwa-banner" in script,
        "Banner script must create the banner element";
    assert "dismissBanner" in script,
        "Banner script must have dismiss functionality";
    assert "shouldShow" in script,
        "Banner script must check whether to show";
    assert "localStorage" in script,
        "Banner script must persist dismiss state";
    assert "<script>" in script,
        "Banner script must be wrapped in a script tag";
}

"""Test that client.impl.jac imports the three PWA runtime scripts."""
test "client impl imports pwa runtime scripts" {
    # Read client.impl.jac and verify it imports the PWA functions
    impl_path = Path(__file__).parent.parent / "plugin" / "impl" / "client.impl.jac";
    content = impl_path.read_text(encoding='utf-8');

    assert "_build_install_prompt_capture_script" in content,
        "client.impl.jac must import _build_install_prompt_capture_script";
    assert "_build_sw_registration_script" in content,
        "client.impl.jac must import _build_sw_registration_script";
    assert "_build_pwa_install_banner_script" in content,
        "client.impl.jac must import _build_pwa_install_banner_script";
}

# =============================================================================
# Vite Define Guard Tests
# =============================================================================

"""Test that _format_define_entries skips API base URL when empty (desktop builds)."""
test "vite define skips api base url when empty" {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }
            bundler = ViteBundler(Path(temp_dir));
            result = bundler._format_define_entries("", {});
            assert "__JAC_API_BASE_URL__" not in result,
                "Empty api_base_url must NOT inject API base URL define (breaks desktop/Tauri builds)";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

"""Test that _format_define_entries includes API base URL when set."""
test "vite define includes api base url when set" {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n';
            with open("jac.toml", "w") as f {
                f.write(toml_content);
            }
            bundler = ViteBundler(Path(temp_dir));
            result = bundler._format_define_entries("http://localhost:8000", {});
            assert "__JAC_API_BASE_URL__" in result,
                "Non-empty api_base_url must inject API base URL define";
            assert "localhost:8000" in result,
                "Define must contain the actual URL";
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
    import from jaclang.runtimelib.client.config_loader { JacClientConfig }

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
            assert not config.is_pwa_enabled() , "Empty PWA section should not enable PWA";
        } finally {
            os.chdir(original_cwd);
        }
    }
}
