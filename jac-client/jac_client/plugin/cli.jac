"""Command line interface tool for the Jac Client.

This module extends the core `create` command to add client-side (frontend)
project setup via the --cl flag using the extend_command API.
"""

import os;
import re;
import sys;
import pathlib;
import subprocess;
import shutil;
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, HookContext }
import from jaclang.pycore.runtime { hookimpl }
import from jaclang.project.config { find_project_root }

"""Jac CLI extensions for client-side development."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Extend core create command to add --cl flag for client-side setup.""";
        registry = get_registry();

        # Extend the core 'create' command with client-specific arguments
        registry.extend_command(
            command_name="create",
            args=[
                Arg.create(
                    "cl",
                    typ=bool,
                    default=False,
                    help="Include client-side (frontend) setup",
                    short="c"
                ),
                Arg.create(
                    "skip",
                    typ=bool,
                    default=False,
                    help="Skip installing default packages (only for --cl)",
                    short="s"
                ),
                Arg.create(
                    "verbose",
                    typ=bool,
                    default=False,
                    help="Show detailed output during installation",
                    short="v"
                ),

            ],
            pre_hook=_handle_client_create,
            source="jac-client"
        );
    }
}

"""Pre-hook to handle --cl flag for client-side project creation."""
def _handle_client_create(ctx: HookContext) -> None {
    # Check if --cl flag is set
    cl_flag = ctx.get_arg("cl", False);
    if not cl_flag {
        # Let core create command run normally
        return;
    }

    # Handle client-side project creation
    cwd = pathlib.Path(os.getcwd());
    name = ctx.get_arg("name", "main");
    force = ctx.get_arg("force", False);
    skip_install = ctx.get_arg("skip", False);
    verbose = ctx.get_arg("verbose", False);

    try {
        _create_client_project(cwd, name, force, skip_install, verbose);
        # Cancel core handler with success code
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except SystemExit as e {
        # Preserve exit code from sys.exit() calls
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", e.code if e.code is not None else 1);
    } except Exception as e {
        print(f"Error creating client project: {e}", file=sys.stderr);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

"""Create a client-side Jac project with organized folder structure."""
def _create_client_project(
    cwd: pathlib.Path,
    name: str,
    force: bool,
    skip: bool = False,
    verbose: bool = False
) -> None {
    project_name = name or cwd.name;

    if not project_name or project_name == 'main' {
        print(
            "Error: Project name is required for client projects. Use: jac create --cl <name>",
            file=sys.stderr
        );
        <>exit(1);
    }

    if not re.match('^[a-zA-Z0-9_-]+$', project_name) {
        print(
            "Error: Project name must contain only letters, numbers, hyphens, and underscores",
            file=sys.stderr
        );
        <>exit(1);
    }

    existing = find_project_root(cwd);
    if existing and not force {
        (project_root, toml_path) = existing;
        print(f"Already in a Jac project: {toml_path}", file=sys.stderr);
        print("Use --force to reinitialize.", file=sys.stderr);
        <>exit(1);
    }

    project_path: pathlib.Path;
    if name and name != cwd.name {
        project_path = cwd / name;
        if project_path.exists() and not force {
            print(f"Error: Directory '{name}' already exists", file=sys.stderr);
            <>exit(1);
        }
        project_path.mkdir(parents=True, exist_ok=True);
    } else {
        project_path = cwd;
    }

    print(f"Creating Jac client application: {project_name}");

    components_dir = project_path / "components";
    components_dir.mkdir(parents=True, exist_ok=True);

    assets_dir = project_path / "assets";
    assets_dir.mkdir(parents=True, exist_ok=True);

    (project_path / ".jac" / "client").mkdir(parents=True, exist_ok=True);

    toml_path = project_path / "jac.toml";
    toml_content = f'''[project]
name = "{project_name}"
version = "1.0.0"
description = "Jac client application: {project_name}"
entry-point = "main.jac"

[dependencies.npm]
"jac-client-node" = "1.0.3"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[serve]
base_route_app = "app"

[plugins.client]
# Vite bundler configuration (optional overrides)
# vite.plugins = []
# vite.build = {{}}
''';
    with open(toml_path, 'w') as f {
        f.write(toml_content);
    }
    print(f"Created {toml_path}");

    main_jac_content = '''"""Main entry point for the Jac client application."""

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
''';
    with open(project_path / "main.jac", 'w') as f {
        f.write(main_jac_content);
    }
    print("Created main.jac");

    button_cl_jac_content = '''"""Button component for the Jac client application."""

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
''';
    with open(components_dir / "Button.cl.jac", 'w') as f {
        f.write(button_cl_jac_content);
    }
    print("Created components/Button.cl.jac");

    readme_content = f'''  # {project_name}


A Jac client-side application with React support.

## Project Structure

```
{project_name}/
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
cl import from .components.Button {{ Button }}
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```
''';
    with open(project_path / "README.md", 'w') as f {
        f.write(readme_content);
    }
    print("Created README.md");

    _create_gitignore(project_path);

    # Install default packages unless --skip is specified
    if not skip {
        print("\nInstalling default packages...");
        _install_default_packages(project_path, verbose);
    }

    print(f"\nProject '{project_name}' created successfully!");
    if name and name != cwd.name {
        print("\nNext steps:");
        print(f"  cd {name}");
        print("  jac start main.jac");
    } else {
        print("\nNext steps:");
        print("  jac start main.jac");
    }
}

"""Create .gitignore file with client-specific entries."""
def _create_gitignore(project_path: pathlib.Path) -> None {
    gitignore_entries = [
        "# Jac project",
        "packages/",
        ".jac_cache/",
        "*.jbc",
        "*.jir",
        "__jaccache__/",
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
        "# Jac build artifacts",
        ".jac/",
        "*.session",
        "*.session.*"
    ];

    gitignore_path = project_path / ".gitignore";
    if gitignore_path.exists() {
        with open(gitignore_path, "r") as f {
            existing_content = f.read();
        }
        new_entries: list = [];
        for entry in gitignore_entries {
            if entry and entry not in existing_content {
                new_entries.append(entry);
            }
        }
        if new_entries {
            with open(gitignore_path, "a") as f {
                f.write("\n" + "\n".join(new_entries));
            }
            print("Updated .gitignore");
        }
    } else {
        with open(gitignore_path, "w") as f {
            f.write("\n".join(gitignore_entries) + "\n");
        }
        print("Created .gitignore");
    }
}

"""Install default npm packages in .jac/client directory."""
def _install_default_packages(
    project_path: pathlib.Path, verbose: bool = False
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

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

        # Get project name from jac.toml or use directory name
        project_name = project_path.name;

        # Create ViteBundler instance (it will load config internally)
        bundler = ViteBundler(project_path);

        # Generate package.json with default packages (defaults are added automatically)
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

        # Always copy the generated package.json to .jac/client/ for npm install
        shutil.copy2(configs_package_json, build_package_json);

        # Read package data for verbose output
        import json;
        with open(configs_package_json, 'r') as f {
            pkg_data = json.load(f);
        }
        deps = pkg_data.get('dependencies', {});
        dev_deps = pkg_data.get('devDependencies', {});

        if verbose {
            # Verbose mode: show detailed package list and stream npm output
            if deps {
                print("  Dependencies:");
                for (name, version) in deps.items() {
                    print(f"    - {name}@{version}");
                }
            }
            if dev_deps {
                print("  Dev dependencies:");
                for (name, version) in dev_deps.items() {
                    print(f"    - {name}@{version}");
                }
            }
            print("\nRunning npm install...");
        }

        # Run npm install in .jac/client/ directory
        try {
            if verbose {
                # Stream output for visibility in verbose mode
                subprocess.run(
                    ['npm', 'install', '--progress'], cwd=client_dir, check=True
                );
            } else {
                # Quiet mode: capture output
                subprocess.run(
                    ['npm', 'install'],
                    cwd=client_dir,
                    check=True,
                    capture_output=True,
                    text=True
                );
            }

            # Move package-lock.json to configs/ if it was created
            build_package_lock = client_dir / 'package-lock.json';
            configs_dir = client_dir / 'configs';
            configs_package_lock = configs_dir / 'package-lock.json';
            if build_package_lock.exists() {
                configs_dir.mkdir(parents=True, exist_ok=True);
                if configs_package_lock.exists() {
                    configs_package_lock.unlink();
                }
                shutil.move(str(build_package_lock), str(configs_package_lock));
            }

            print("Default packages installed successfully");
        } except subprocess.CalledProcessError as e {
            if verbose {
                print(
                    f"Warning: Failed to install packages (exit code {e.returncode})",
                    file=sys.stderr
                );
            } else {
                print(
                    f"Warning: Failed to install packages: {e.stderr}", file=sys.stderr
                );
            }
            print("You can install packages later with: jac add --cl", file=sys.stderr);
        } except FileNotFoundError {
            print(
                "Warning: npm command not found. Install Node.js and npm to install packages.",
                file=sys.stderr
            );
            print("You can install packages later with: jac add --cl", file=sys.stderr);
        } finally {
            # Clean up temporary package.json in .jac/client/
            if build_package_json.exists() {
                build_package_json.unlink();
            }
        }
    } except Exception as e {
        print(f"Warning: Could not install default packages: {e}", file=sys.stderr);
        print("You can install packages later with: jac add --cl", file=sys.stderr);
    }
}
