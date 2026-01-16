"""Plugin configuration hooks for jac-client.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.client] section
- npm dependency type for [dependencies.npm] section
"""

import os;
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
            "install_dir": ".jac/client/configs",
            "install_handler": _npm_install_handler,
            "install_all_handler": _npm_install_all_handler,
            "remove_handler": _npm_remove_handler
        };
    }

    """Register the client project template."""
    @hookimpl
    static def register_project_template -> dict[str, Any] {
        return {
            "name": "client",
            "description": "Jac project with frontend client setup",
            "config": {
                "project": {
                    "name": "{{name}}",
                    "version": "1.0.0",
                    "description": "Jac client application: {{name}}",
                    "entry-point": "main.jac"
                },
                "dependencies": {},
                "dependencies.npm": {"jac-client-node": "1.0.3"},
                "dependencies.npm.dev": {"@jac-client/dev-deps": "1.0.0"},
                "dev-dependencies": {"watchdog": ">=3.0.0"},
                "serve": {"base_route_app": "app"},
                "plugins.client": {}
            },
            "files": {
                "main.jac": _CLIENT_MAIN_JAC,
                "components/Button.cl.jac": _CLIENT_BUTTON_JAC,
                "README.md": _CLIENT_README
            },
            "directories": ["components", "assets", ".jac/client"],
            "gitignore_entries": [
                "# Ignore all build artifacts in .jac directory",
                "*"
            ],
            "root_gitignore_entries": [
                "# Jac project",
                "packages/",
                "*.jbc",
                "*.jir",
                "",
                "# Python",
                "__pycache__/",
                "*.py[cod]",
                ".venv/",
                "venv/",
                "",
                "# IDE",
                ".idea/",
                ".vscode/",
                "*.swp",
                "",
                "# Node.js",
                "node_modules/",
                "",
                "# Build artifacts",
                ".jac/",
                "*.session",
                "*.session.*"
            ],
            "post_create": _post_create_client
        };
    }
}

# ===============================================================================
# Client Template Content
# ===============================================================================
glob _CLIENT_MAIN_JAC:
         str = '''"""Main entry point for the Jac client application."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect }
cl import from .components.Button { Button }

# Client-side component
cl {
    def:pub app() -> any {
        has count: int = 0;

        useEffect(lambda -> None {
            console.log("Count updated:", count);
        }, [count]);

        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda -> None { count = count + 1; }}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda -> None { count = 0; }}
                    variant="secondary"
                />
            </div>
        </div>;
    }
}
''',
     _CLIENT_BUTTON_JAC: str = '''"""Button component for the Jac client application."""

def:pub Button(label: str, onClick: any, variant: str = "primary", disabled: bool = False) -> any {
    base_styles = {
        "padding": "0.75rem 1.5rem",
        "fontSize": "1rem",
        "fontWeight": "600",
        "borderRadius": "0.5rem",
        "border": "none",
        "cursor": "not-allowed" if disabled else "pointer",
        "transition": "all 0.2s ease"
    };

    variant_styles = {
        "primary": {
            "backgroundColor": "#9ca3af" if disabled else "#3b82f6",
            "color": "#ffffff"
        },
        "secondary": {
            "backgroundColor": "#e5e7eb" if disabled else "#6b7280",
            "color": "#ffffff"
        }
    };

    return <button
        style={{**base_styles, **variant_styles[variant]}}
        onClick={onClick}
        disabled={disabled}
    >
        {label}
    </button>;
}
''',
     _CLIENT_README: str = '''# {{name}}

A Jac client-side application with React support.

## Project Structure

```
{{name}}/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.cl.jac     # Example Jac component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac start main.jac
```

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```
''';

# ===============================================================================
# Post-create Hook for Client Template
# ===============================================================================
"""Post-create hook to install npm packages after project creation."""
def _post_create_client(project_path: Path, project_name: str) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import shutil;

    # Check if npm installation should be skipped
    if os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL") {
        return;
    }

    print("\nInstalling default npm packages...");

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

        # Copy package.json to .jac/client/ for npm install
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

        # Run npm install
        try {
            subprocess.run(
                ['npm', 'install'],
                cwd=client_dir,
                check=True,
                capture_output=True,
                text=True
            );

            # Move package-lock.json to configs/ if it was created
            build_package_lock = client_dir / 'package-lock.json';
            configs_package_lock = client_dir / 'configs' / 'package-lock.json';
            if build_package_lock.exists() {
                if configs_package_lock.exists() {
                    configs_package_lock.unlink();
                }
                shutil.move(str(build_package_lock), str(configs_package_lock));
            }

            print("Default packages installed successfully");
        } except subprocess.CalledProcessError as e {
            print(f"Warning: Failed to install packages: {e.stderr}", file=sys.stderr);
            print("You can install packages later with: jac add --cl", file=sys.stderr);
        } except FileNotFoundError {
            print(
                "Warning: npm command not found. Install Node.js and npm to install packages.",
                file=sys.stderr
            );
            print("You can install packages later with: jac add --cl", file=sys.stderr);
        } finally {
            # Clean up temporary package.json
            if build_package_json.exists() {
                build_package_json.unlink();
            }
        }
    } except Exception as e {
        print(f"Warning: Could not install default packages: {e}", file=sys.stderr);
        print("You can install packages later with: jac add --cl", file=sys.stderr);
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

"""Regenerate package.json from jac.toml and run npm install."""
def _regenerate_and_install(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import shutil;

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();

    # Install to .jac/client/ directory where babel processor expects it
    client_dir = bundler._get_client_dir();
    client_dir.mkdir(parents=True, exist_ok=True);

    # Copy package.json to .jac/client/ for npm install
    configs_package_json = client_dir / 'configs' / 'package.json';
    build_package_json = client_dir / 'package.json';
    if configs_package_json.exists() {
        shutil.copy2(configs_package_json, build_package_json);
    }

    try {
        subprocess.run(
            ["npm", "install"],
            cwd=client_dir,
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
        # Clean up temporary package.json
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        # Move package-lock.json to configs/ if it exists
        build_package_lock = client_dir / 'package-lock.json';
        if build_package_lock.exists() {
            configs_package_lock = client_dir / 'configs' / 'package-lock.json';
            if configs_package_lock.exists() {
                configs_package_lock.unlink();
            }
            build_package_lock.rename(configs_package_lock);
        }
    }
}
