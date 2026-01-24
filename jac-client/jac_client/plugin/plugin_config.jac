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
            "cli_flag": "--pnpm",
            "install_dir": ".jac/client/configs",
            "install_handler": _pnpm_install_handler,
            "install_all_handler": _pnpm_install_all_handler,
            "remove_handler": _pnpm_remove_handler
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
"""Post-create hook to ensure Node.js is installed and optionally install npm packages."""
def _post_create_client(project_path: Path, project_name: str) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.utils.node_installer { NodeInstaller }
    import from jaclang.cli.console { console }
    import shutil;

    # First, ensure Node.js is installed
    console.print();
    with console.status(
        "[cyan]Checking Node.js installation...[/cyan]", spinner="dots"
    ) as status {
        node_result = NodeInstaller.ensure_node_installed(interactive=True);
        node_installed = node_result[0];
        message = node_result[1];
        was_just_installed = node_result[2];
    }

    if not node_installed {
        console.warning(f"Node.js is required for client development");
        console.print(f"\n  {message}", file=sys.stderr);
        console.print(
            "  After installing Node.js and pnpm, run: jac add --cl\n",
            style="muted",
            file=sys.stderr
        );
        return;
    }

    console.print(f"  ✔ {message}", style="success");

    # Check if npm package installation should be skipped
    if os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL") {
        console.print(
            "\n  ⏭ Skipping npm package installation (JAC_CLIENT_SKIP_NPM_INSTALL is set)",
            style="muted"
        );
        console.print(
            "  Run 'jac add --npm' when ready to install packages.\n", style="muted"
        );
        return;
    }

    # Ensure pnpm is installed
    console.print();
    with console.status("[cyan]Checking pnpm installation...[/cyan]", spinner="dots") as status {
        pnpm_result = NodeInstaller.ensure_pnpm_installed(interactive=True);
        pnpm_installed = pnpm_result[0];
        pnpm_message = pnpm_result[1];
        pnpm_just_installed = pnpm_result[2];
    }

    if not pnpm_installed {
        console.warning(f"pnpm is required for package management");
        console.print(f"\n  {pnpm_message}", file=sys.stderr);
        console.print(
            "  After installing pnpm, run: jac add --cl\n",
            style="muted",
            file=sys.stderr
        );
        return;
    }

    console.print(f"  ✔ {pnpm_message}", style="success");

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

        # Generate .npmrc
        bundler.create_npmrc();

        # Ensure .jac/client directory exists
        client_dir = bundler._get_client_dir();
        client_dir.mkdir(parents=True, exist_ok=True);

        # Copy package.json and .npmrc to .jac/client/ for pnpm install
        configs_package_json = client_dir / 'configs' / 'package.json';
        build_package_json = client_dir / 'package.json';
        configs_npmrc = client_dir / 'configs' / '.npmrc';
        build_npmrc = client_dir / '.npmrc';

        if not configs_package_json.exists() {
            print(
                "Warning: package.json was not generated, skipping package installation",
                file=sys.stderr
            );
            return;
        }
        shutil.copy2(configs_package_json, build_package_json);
        if configs_npmrc.exists() {
            shutil.copy2(configs_npmrc, build_npmrc);
        } else {
            print(
                "Warning: .npmrc was not generated, skipping peerDependencies installation",
                file=sys.stderr
            );
        }

        # Run pnpm install using NodeInstaller to handle NVM environment
        try {
            console.print("\n  ⏳ Installing npm packages...\n", style="cyan");
            NodeInstaller.run_pnpm_with_nvm(
                ['install'], cwd=client_dir, timeout=300
            );

            # CHANGED: Move pnpm-lock.yaml to configs/ if it was created
            build_pnpm_lock = client_dir / 'pnpm-lock.yaml';
            configs_pnpm_lock = client_dir / 'configs' / 'pnpm-lock.yaml';
            if build_pnpm_lock.exists() {
                if configs_pnpm_lock.exists() {
                    configs_pnpm_lock.unlink();
                }
                shutil.move(str(build_pnpm_lock), str(configs_pnpm_lock));
            }

            console.print("  ✔ pnpm packages installed", style="success");
        } except subprocess.CalledProcessError as e {
            console.warning(f"Failed to install packages: {e.stderr}");
            console.print(
                "  💡 You can install packages later with: jac add --cl\n",
                style="muted"
            );
        } except FileNotFoundError {
            console.warning(
                "pnpm command not found. This may require reloading your shell."
            );
            console.print(
                "  💡 You can install packages later with: jac add --cl\n",
                style="muted"
            );
        } finally {
            # Clean up temporary files
            if build_package_json.exists() {
                build_package_json.unlink();
            }
            if build_npmrc.exists() {
                build_npmrc.unlink();
            }
        }
    } except Exception as e {
        console.warning(f"Could not install default packages: {e}");
        console.print(
            "  💡 You can install packages later with: jac add --cl\n", style="muted"
        );
    }

    # If pnpm was just installed, inform user
    if pnpm_just_installed {
        console.print();
        console.info("pnpm was just installed globally");
        console.print(
            "\n  💡 pnpm commands work immediately via global installation",
            style="info"
        );
        console.print();
    }

    # If Node.js was just installed, offer to restart terminal for full integration
    if was_just_installed {
        console.print();
        console.info("Node.js was just installed via NVM");
        console.print(
            "\n  For Node.js to be available in your current shell:", style="muted"
        );
        console.print("    1. Run: source ~/.nvm/nvm.sh", style="muted");
        console.print("    2. Or restart your terminal", style="muted");
        console.print("\n  💡 pnpm commands from jac work immediately", style="info");
        console.print();
    }
}

# ===============================================================================
# NPM Dependency Handlers
# ===============================================================================
"""Install an npm package."""
def _pnpm_install_handler(
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
def _pnpm_install_all_handler(config: JacConfig) -> None {
    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    _regenerate_and_install(Path(str(config.project_root)));
}

"""Remove an npm package."""
def _pnpm_remove_handler(
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

"""Regenerate package.json from jac.toml and run pnpm install."""
def _regenerate_and_install(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.utils.node_installer { NodeInstaller }
    import shutil;

    # Ensure Node.js is installed before proceeding
    node_result = NodeInstaller.ensure_node_installed(interactive=True);
    node_installed = node_result[0];
    message = node_result[1];
    was_just_installed = node_result[2];

    if not node_installed {
        raise RuntimeError(
            f"Node.js installation required:\n{message}\n" + "Please install Node.js and try again."
        ) ;
    }

    # Ensure pnpm is installed
    pnpm_result = NodeInstaller.ensure_pnpm_installed(interactive=True);
    pnpm_installed = pnpm_result[0];
    pnpm_message = pnpm_result[1];
    pnpm_just_installed = pnpm_result[2];

    if not pnpm_installed {
        raise RuntimeError(
            f"pnpm installation required:\n{pnpm_message}\n" + "Please install pnpm and try again."
        ) ;
    }

    # Inform user if Node.js was just installed
    if was_just_installed {
        print(
            "\nNote: Node.js was just installed. pnpm commands will work via NVM sourcing."
        );
    }

    # Inform user if pnpm was just installed
    if pnpm_just_installed {
        print("\nNote: pnpm was just installed globally.");
    }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();
    bundler.create_npmrc();

    # Install to .jac/client/ directory where babel processor expects it
    client_dir = bundler._get_client_dir();
    client_dir.mkdir(parents=True, exist_ok=True);

    # Copy package.json and .npmrc to .jac/client/ for pnpm install
    configs_package_json = client_dir / 'configs' / 'package.json';
    configs_npmrc = client_dir / 'configs' / '.npmrc';
    build_package_json = client_dir / 'package.json';
    build_npmrc = client_dir / '.npmrc';
    if configs_package_json.exists() {
        shutil.copy2(configs_package_json, build_package_json);
    }
    if configs_npmrc.exists() {
        shutil.copy2(configs_npmrc, build_npmrc);
    }

    try {
        # Use NodeInstaller.run_pnpm_with_nvm to handle NVM environment
        NodeInstaller.run_pnpm_with_nvm(["install"], cwd=client_dir, timeout=300);
    } except subprocess.CalledProcessError as e {
        raise RuntimeError(f"Failed to install pnpm packages: {e.stderr}") from e ;
    } except FileNotFoundError {
        raise RuntimeError(
            "pnpm command not found. This may require reloading your shell after Node.js installation."
        ) from None ;
    } finally {
        # Clean up temporary files
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        if build_npmrc.exists() {
            build_npmrc.unlink();
        }
        # Move pnpm-lock.yaml to configs/ if it exists
        build_pnpm_lock = client_dir / 'pnpm-lock.yaml';
        if build_pnpm_lock.exists() {
            configs_pnpm_lock = client_dir / 'configs' / 'pnpm-lock.yaml';
            if configs_pnpm_lock.exists() {
                configs_pnpm_lock.unlink();
            }
            build_pnpm_lock.rename(configs_pnpm_lock);
        }
    }
}
