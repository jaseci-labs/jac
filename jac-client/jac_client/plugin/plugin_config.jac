"""Plugin configuration hooks for jac-client.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.client] section
- npm dependency type for [dependencies.npm] section
- Project templates (client, fullstack)
"""

import os;
import subprocess;
import sys;
import json;
import from pathlib { Path }
import from typing { Any }
import from jaclang.pycore.runtime { hookimpl }
import from jaclang.project.config { JacConfig }

"""Plugin configuration hooks for jac-client."""
class JacClientPluginConfig {
    """Return plugin metadata."""
    @hookimpl
    static def get_plugin_metadata -> dict[str, Any] {
        return {
            "name": "client",
            "version": "1.0.0",
            "description": "Jac client-side rendering with Vite bundling"
        };
    }

    """Return the plugin's configuration schema for [plugins.client]."""
    @hookimpl
    static def get_config_schema -> dict[str, Any] {
        return {
            "section": "client",
            "options": {
                "vite": {
                    "type": "dict",
                    "default": {},
                    "description": "Vite bundler configuration",
                    "nested": {
                        "plugins": {
                            "type": "list",
                            "default": [],
                            "description": "Vite plugins to include"
                        },
                        "lib_imports": {
                            "type": "list",
                            "default": [],
                            "description": "Library imports for vite.config.js"
                        },
                        "build": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite build options"
                        },
                        "server": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite dev server options"
                        },
                        "resolve": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite resolve options"
                        }
                    }
                },
                "ts": {
                    "type": "dict",
                    "default": {},
                    "description": "TypeScript configuration overrides"
                },
                "configs": {
                    "type": "dict",
                    "default": {},
                    "description": "Generate config files for npm packages. Keys are config names (e.g., 'postcss', 'tailwind'), values are the config objects to export."
                }
            }
        };
    }

    """Register npm as a dependency type for [dependencies.npm]."""
    @hookimpl
    static def register_dependency_type -> dict[str, Any] {
        return {
            "name": "npm",
            "dev_name": "npm.dev",
            "cli_flag": "--npm",
            "install_dir": ".jac/client/configs",
            "install_handler": _npm_install_handler,
            "install_all_handler": _npm_install_all_handler,
            "remove_handler": _npm_remove_handler
        };
    }

    """Register the client and fullstack project templates."""
    @hookimpl
    static def register_project_template -> list[dict[str, Any]] {
        templates: list[dict[str, Any]] = [];

        # Load templates from bundled JSON files
        for template_name in ["client", "fullstack"] {
            template = _load_template(template_name);
            if template {
                templates.append(template);
            }
        }

        return templates;
    }
}

# ===============================================================================
# Template Loader
# ===============================================================================
"""Load a template from bundled JSON file."""
def _load_template(template_name: str) -> dict[str, Any] | None {
    # Find the template JSON file relative to this module
    # plugin_config.jac is in jac_client/plugin/, so .parent.parent = jac_client/
    module_dir = Path(__file__).parent.parent;  # jac_client directory
    template_path = module_dir / "templates" / f"{template_name}.jacpack";

    if not template_path.exists() {
        # Fallback: look in installed package location
        import from importlib.resources { files }
        try {
            package_files = files("jac_client");
            template_path = Path(str(package_files)) / "templates" / f"{template_name}.jacpack";
        } except Exception {
            return None;
        }
    }

    if not template_path.exists() {
        return None;
    }

    try {
        with open(template_path, "r") as f {
            data = json.load(f);
        }

        # Attach the post_create hook
        data["post_create"] = _post_create_client;

        return data;
    } except Exception as e {
        print(
            f"Warning: Could not load {template_name} template: {e}", file=sys.stderr
        );
        return None;
    }
}

# ===============================================================================
# Post-create Hook for Client Template
# ===============================================================================
"""Post-create hook to ensure Bun is installed and optionally install packages."""
def _post_create_client(project_path: Path, project_name: str) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jaclang.cli.console { console }
    import from jac_client.plugin.utils { ensure_bun_available }

    # First, ensure Bun is installed (prompt to install if not)
    console.print();
    if not ensure_bun_available() {
        console.warning("Bun is required for client development");
        console.print("  After installing Bun, run: jac add --cl\n", style="muted");
        return;
    }

    console.print("  ✔ Bun is installed", style="success");

    # Check if package installation should be skipped
    if os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL") {
        console.print(
            "\n  ⏭ Skipping package installation (JAC_CLIENT_SKIP_NPM_INSTALL is set)",
            style="muted"
        );
        console.print(
            "  Run 'jac add --npm' when ready to install packages.\n", style="muted"
        );
        return;
    }

    console.print();

    try {
        # Verify jac.toml exists
        toml_path = project_path / "jac.toml";
        if not toml_path.exists() {
            print(
                "Warning: jac.toml not found, skipping package installation",
                file=sys.stderr
            );
            return;
        }

        # Create ViteBundler instance
        bundler = ViteBundler(project_path);

        # Generate package.json with default packages
        bundler.create_package_json(project_name=project_name);

        # Ensure .jac/client directory exists
        client_dir = bundler._get_client_dir();
        client_dir.mkdir(parents=True, exist_ok=True);

        # Copy package.json to .jac/client/ for bun install
        configs_package_json = client_dir / 'configs' / 'package.json';
        build_package_json = client_dir / 'package.json';

        if not configs_package_json.exists() {
            print(
                "Warning: package.json was not generated, skipping package installation",
                file=sys.stderr
            );
            return;
        }

        shutil.copy2(configs_package_json, build_package_json);

        # Run bun install (ensure bun is available first)
        import from jac_client.plugin.utils { ensure_bun_available }
        if not ensure_bun_available() {
            console.warning("Bun is required. Install manually: https://bun.sh");
            console.print(
                "  💡 You can install packages later with: jac add --cl\n",
                style="muted"
            );
            # Clean up temporary package.json
            if build_package_json.exists() {
                build_package_json.unlink();
            }
            return;
        }

        try {
            console.print("\n  ⏳ Installing packages...\n", style="cyan");
            subprocess.run(['bun', 'install'], cwd=client_dir, check=True, timeout=300);

            # Move bun.lockb to configs/ if it was created
            build_bun_lockb = client_dir / 'bun.lockb';
            configs_bun_lockb = client_dir / 'configs' / 'bun.lockb';
            if build_bun_lockb.exists() {
                if configs_bun_lockb.exists() {
                    configs_bun_lockb.unlink();
                }
                shutil.move(str(build_bun_lockb), str(configs_bun_lockb));
            }

            console.print("  ✔ Packages installed", style="success");
        } except subprocess.CalledProcessError as e {
            console.warning(f"Failed to install packages: {e}");
            console.print(
                "  💡 You can install packages later with: jac add --cl\n",
                style="muted"
            );
        } finally {
            # Clean up temporary package.json
            if build_package_json.exists() {
                build_package_json.unlink();
            }
        }
    } except Exception as e {
        console.warning(f"Could not install default packages: {e}");
        console.print(
            "  💡 You can install packages later with: jac add --cl\n", style="muted"
        );
    }
}

# ===============================================================================
# NPM Dependency Handlers
# ===============================================================================
"""Install an npm package."""
def _npm_install_handler(
    config: JacConfig,
    package_name: str,
    version: str | None = None,
    is_dev: bool = False
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    # Add to config (core JacConfig handles this)
    package_version: str = version or "latest";
    config.add_dependency(package_name, package_version, dev=is_dev, dep_type="npm");
    config.save();

    # Generate package.json and run npm install
    _regenerate_and_install(Path(str(config.project_root)));
}

"""Install all npm packages from jac.toml."""
def _npm_install_all_handler(config: JacConfig) -> None {
    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    _regenerate_and_install(Path(str(config.project_root)));
}

"""Remove an npm package."""
def _npm_remove_handler(
    config: JacConfig, package_name: str, is_dev: bool = False
) -> None {
    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    project_dir: Path = Path(str(config.project_root));

    # Remove from config (core JacConfig handles this)
    result = config.remove_dependency(package_name, dev=is_dev, dep_type="npm");
    if not result {
        deps_key = "dev-dependencies" if is_dev else "dependencies";
        raise RuntimeError(f'Package "{package_name}" not found in {deps_key}') ;
    }

    config.save();

    # Regenerate package.json and run npm install
    _regenerate_and_install(project_dir);
}

"""Regenerate package.json from jac.toml and run bun install."""
def _regenerate_and_install(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.utils { ensure_bun_available }
    import shutil;

    # Ensure Bun is installed before proceeding (prompt to install if not)
    if not ensure_bun_available() {
        raise RuntimeError("Bun is required. Install manually: https://bun.sh") from None ;
    }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();

    # Install to .jac/client/ directory
    client_dir = bundler._get_client_dir();
    client_dir.mkdir(parents=True, exist_ok=True);

    # Copy package.json to .jac/client/ for bun install
    configs_package_json = client_dir / 'configs' / 'package.json';
    build_package_json = client_dir / 'package.json';
    if configs_package_json.exists() {
        shutil.copy2(configs_package_json, build_package_json);
    }

    try {
        # Run bun install
        subprocess.run(['bun', 'install'], cwd=client_dir, check=True, timeout=300);
    } except subprocess.CalledProcessError as e {
        raise RuntimeError(f"Failed to install packages: {e}") from e ;
    } finally {
        # Clean up temporary package.json
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        # Move bun.lockb to configs/ if it exists
        build_bun_lockb = client_dir / 'bun.lockb';
        if build_bun_lockb.exists() {
            configs_bun_lockb = client_dir / 'configs' / 'bun.lockb';
            if configs_bun_lockb.exists() {
                configs_bun_lockb.unlink();
            }
            build_bun_lockb.rename(configs_bun_lockb);
        }
    }
}
