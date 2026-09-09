"""Tests for the PWA decoration of the web build ([client.pwa])."""

import os;
import tempfile;
import from pathlib { Path }

"""Create a minimal jac.toml file for PWA testing."""
def _create_jac_toml_with_pwa(temp_dir: str, pwa_config: dict | None = None) -> str {
    pwa_section = "";
    if pwa_config is not None {
        pwa_lines = ["[client.pwa]"];
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
react = "^19.2.0"
react-dom = "^19.2.0"
react-router-dom = "^6.22.0"
react-error-boundary = "^5.0.0"

[dependencies.npm.dev]
vite = "^6.4.1"
"@vitejs/plugin-react" = "^4.2.1"
typescript = "^5.3.3"
"@types/react" = "^19.2.0"
"@types/react-dom" = "^19.2.0"

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.vite_bundler { ViteBundler }
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.vite_bundler { ViteBundler }
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
    import from jaclang.client.config_loader { JacClientConfig }

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
# PWA Empty Section Edge Case
# =============================================================================
"""Test PWA is enabled with empty section."""
test "pwa enabled with empty section" {
    import from jaclang.client.config_loader { JacClientConfig }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create jac.toml with empty PWA section (just the header)
            toml_content = '[project]\nname = "test-app"\nversion = "1.0.0"\n\n[client.pwa]\n';
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

# =============================================================================
# PWA is a decoration of the web build, not a target of its own
# =============================================================================
"""A `[client.pwa]` table turns the web target's build into a PWA: there is no
separate PWA target and no `--client pwa` flag any more. WebTarget.build()
applies the decoration through apply_pwa() when the table is present, and
WebTarget.setup() prepares the icons the same way."""
test "web target applies pwa when the client pwa table is present" {
    import from pathlib { Path as _P }
    import jaclang.client.targets.web_target as web_target_mod;

    targets_dir = _P(web_target_mod.__file__).parent;
    assert not (targets_dir / "pwa_target.jac").exists() , (
        "pwa_target.jac must not come back: PWA is a web build decoration"
    );
    assert not (targets_dir / "impl" / "pwa_target.impl.jac").exists();
    assert (targets_dir / "pwa_build.jac").exists() , "the PWA helpers live in pwa_build.jac";
    impl_src = (targets_dir / "impl" / "web_target.impl.jac").read_text(
        encoding="utf-8"
    );
    build_section = impl_src.split("impl WebTarget.build")[1];
    assert "_pwa_enabled(project_dir)" in build_section , (
        "WebTarget.build must consult [client.pwa] before decorating"
    );
    assert "apply_pwa(dist_dir, project_dir)" in build_section , (
        "WebTarget.build must apply the PWA decoration to the built dist"
    );
    assert build_section.index("_generate_index_html")
        < build_section.index("apply_pwa(") , (
        "the decoration must run after index.html is written, so it can be edited"
    );
    setup_section = impl_src.split("impl WebTarget.setup")[1].split("impl WebTarget.")[
        0
    ];
    assert "ensure_pwa_icons(project_dir)" in setup_section;
    assert "PWATarget" not in impl_src;
}

"""WebTarget.setup() is the functional half of the seam: with `[client.pwa]`
it prepares `pwa_icons/` in the project, without it the project is untouched."""
test "web target setup prepares pwa icons only for pwa projects" {
    import from jaclang.client.targets.web_target { WebTarget }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir);
        with open(project_dir / "jac.toml", "w") as f {
            f.write('[project]\nname = "plain-app"\nversion = "1.0.0"\n');
        }
        WebTarget().setup(project_dir);
        assert not (project_dir / "pwa_icons").exists() , (
            "a project without [client.pwa] must not grow a pwa_icons/ dir"
        );
        _create_jac_toml_with_pwa(temp_dir, {"theme_color": "#000000"});
        WebTarget().setup(project_dir);
        assert (project_dir / "pwa_icons").is_dir() , (
            "[client.pwa] makes the web target prepare pwa_icons/ on setup"
        );
    }
}

"""apply_pwa() writes the manifest, the service worker and the index.html
hooks into an already-built web dist -- what `jac build` does for a web app
that declares `[client.pwa]`."""
test "apply_pwa decorates a built web dist" {
    import json;
    import from jaclang.project.config { set_config }
    import from jaclang.client.targets.pwa_build { apply_pwa }

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        set_config(None);
        try {
            os.chdir(temp_dir);
            _create_jac_toml_with_pwa(
                temp_dir, {"theme_color": "#ff0000", "install_banner": True}
            );
            project_dir = Path(temp_dir);
            dist_dir = project_dir / ".jac" / "client" / "dist";
            dist_dir.mkdir(parents=True);
            (dist_dir / "client.ABC123.js").write_text("console.log(1);\n");
            (dist_dir / "index.html").write_text(
                "<!DOCTYPE html>\n<html>\n<head>\n<title>t</title>\n</head>\n"
                "<body>\n<div id=\"root\"></div>\n</body>\n</html>\n"
            );
            apply_pwa(dist_dir, project_dir);

            manifest = json.loads((dist_dir / "manifest.json").read_text());
            assert manifest["name"] == "test-pwa-app" , manifest;
            assert manifest["display"] == "standalone";
            assert manifest["theme_color"] == "#ff0000";
            assert manifest["start_url"] == "/";
            assert [i["src"] for i in manifest["icons"]][:2]
                == ["pwa-192x192.png", "pwa-512x512.png"];
            sw = (dist_dir / "sw.js").read_text();
            assert "addEventListener" in sw;
            assert "install" in sw and "fetch" in sw;
            assert "client.ABC123.js" in sw , "the bundle is precached";
            html = (dist_dir / "index.html").read_text();
            assert 'rel="manifest"' in html;
            assert "serviceWorker" in html;
            assert 'name="theme-color" content="#ff0000"' in html;
        } finally {
            os.chdir(original_cwd);
            set_config(None);
        }
    }
}
