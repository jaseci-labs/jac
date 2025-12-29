"""Plugin configuration hooks for jac-client.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.client] section
- npm dependency type for [dependencies.npm] section
"""

import subprocess;
import sys;
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
            "cli_flag": "--cl",
            "install_dir": ".client-build/.jac-client.configs",
            "install_handler": _npm_install_handler,
            "install_all_handler": _npm_install_all_handler,
            "remove_handler": _npm_remove_handler
        };
    }
}

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

    project_dir = config.project_root;

    # Add to config (core JacConfig handles this)
    package_version = version or "latest";
    config.add_dependency(package_name, package_version, dev=is_dev, dep_type="npm");
    config.save();

    # Generate package.json and run npm install
    _regenerate_and_install(project_dir);
}

"""Install all npm packages from jac.toml."""
def _npm_install_all_handler(config: JacConfig) -> None {
    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    _regenerate_and_install(config.project_root);
}

"""Remove an npm package."""
def _npm_remove_handler(
    config: JacConfig, package_name: str, is_dev: bool = False
) -> None {
    if config.project_root is None {
        raise RuntimeError("No project root found") ;
    }

    project_dir = config.project_root;

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

"""Regenerate package.json from jac.toml and run npm install."""
def _regenerate_and_install(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();
    bundler._ensure_root_package_json();

    try {
        subprocess.run(
            ["npm", "install"],
            cwd=project_dir,
            check=True,
            capture_output=True,
            text=True
        );
    } except subprocess.CalledProcessError as e {
        raise RuntimeError(f"Failed to install npm packages: {e.stderr}") from e ;
    } except FileNotFoundError {
        raise RuntimeError(
            "npm command not found. Ensure Node.js and npm are installed."
        ) from None ;
    } finally {
        bundler._cleanup_root_package_files();
    }
}
