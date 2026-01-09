"""Command line interface tool for the Jac Client.

This module extends the core `create` command to add client-side (frontend)
project setup via the --cl flag.
"""

import os;
import re;
import sys;
import pathlib;
import subprocess;
import shutil;
import from jaclang.cli.cmdreg { cmd_registry, CommandPriority }
import from jaclang.pycore.runtime { hookimpl }
import from jaclang.project.config { JacConfig, find_project_root }

"""Jac CLI extensions for client-side development."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Override core create command to add --cl flag for client-side setup.""";

        def create(
            name: str = 'main',
            force: bool = False,
            cl: bool = False,
            skip: bool = False,
            verbose: bool = False
        ) -> None {
            """Initialize a new Jac project.

            Creates a jac.toml configuration file and basic project structure.
            Use --cl to include client-side (frontend) setup with Vite bundling.

            Args:
                name: Project name (default: 'main')
                force: Overwrite existing jac.toml if present
                cl: Include client-side (frontend) setup
                skip: Skip installing default packages (only for --cl projects)
                verbose: Show detailed output during package installation

            Examples:
                jac create
                jac create myapp
                jac create --cl myapp
                jac create --cl --skip myapp
                jac create --cl --verbose myapp
                jac create --force
            """;
            cwd = pathlib.Path(os.getcwd());

            if cl {
                _create_client_project(cwd, name, force, skip, verbose);
            } else {
                _create_core_project(cwd, name, force);
            }
        }

        # Register with PLUGIN priority to override core's create command
        cmd_registry.register(
            create, priority=CommandPriority.PLUGIN, source="jac-client"
        );
    }
}

"""Create a standard Jac project (core behavior)."""
def _create_core_project(cwd: pathlib.Path, name: str, force: bool) -> None {
    project_name = name or cwd.name;

    # Create project directory if name is provided
    if name {
        project_path = cwd / name;
        if project_path.exists() and not force {
            print(
                f"Directory '{name}' already exists. Use --force to overwrite.",
                file=sys.stderr
            );
            <>exit(1);
        }
        project_path.mkdir(parents=True, exist_ok=True);
    } else {
        project_path = cwd;
        # Check if already in a project (only when not creating a new folder)
        existing = find_project_root(cwd);
        if existing and not force {
            (project_root, toml_path) = existing;
            print(f"Already in a Jac project: {toml_path}", file=sys.stderr);
            print("Use --force to reinitialize.", file=sys.stderr);
            <>exit(1);
        }
    }

    toml_path = project_path / "jac.toml";
    if toml_path.exists() and not force {
        print("jac.toml already exists. Use --force to overwrite.", file=sys.stderr);
        <>exit(1);
    }

    toml_content = JacConfig.create_default_toml(project_name);
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    print(f"Created {toml_path}");

    main_jac = project_path / "main.jac";
    if not main_jac.exists() {
        with open(main_jac, "w") as f {
            f.write(
                f'''"""Main entry point for {project_name}."""

with entry {{
    print("Hello from {project_name}!");
}}
'''
            );
        }
        print(f"Created {main_jac}");
    }

    packages_dir = project_path / "packages";
    if not packages_dir.exists() {
        packages_dir.mkdir(parents=True, exist_ok=True);
        print(f"Created {packages_dir}/");
    }

    _create_gitignore(project_path, client=False);

    # Pre-generate cache for the jac compiler
    main_jac_path = project_path / "main.jac";
    try {
        result = subprocess.run(
            [sys.executable, "-m", "jaclang.cli.cli", "check", str(main_jac_path)],
            capture_output=True,
            text=True,
            cwd=str(project_path)
        );
        if result.returncode == 0 {
            print("Pre-generated compiler cache");
        }
    } except Exception {
    # Silently ignore cache generation failures
    }

    print(f"\nProject '{project_name}' initialized successfully!");
    print("\nNext steps:");
    if name {
        print(f"  cd {name}");
    }
    print("  jac run main.jac    # Run the main entry point");
    print("  jac add <package>   # Add dependencies");
    print("  jac install         # Install all dependencies");
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

# Client-side imports
cl import from react { useState, useEffect }
cl import from ".components/Button.tsx" { Button }

# Client-side component
cl {
    def:pub app() -> any {
        [count, setCount] = useState(0);

        useEffect(lambda -> None {
            console.log("Count updated:", count);
        }, [count]);

        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda -> None { setCount(count + 1); }}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda -> None { setCount(0); }}
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

    button_tsx_content = '''import React from 'react';

interface ButtonProps {
  label: string;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  variant = 'primary',
  disabled = false
}) => {
  const baseStyles: React.CSSProperties = {
    padding: '0.75rem 1.5rem',
    fontSize: '1rem',
    fontWeight: '600',
    borderRadius: '0.5rem',
    border: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    transition: 'all 0.2s ease',
  };

  const variantStyles: Record<string, React.CSSProperties> = {
    primary: {
      backgroundColor: disabled ? '#9ca3af' : '#3b82f6',
      color: '#ffffff',
    },
    secondary: {
      backgroundColor: disabled ? '#e5e7eb' : '#6b7280',
      color: '#ffffff',
    },
  };

  return (
    <button
      style={{ ...baseStyles, ...variantStyles[variant] }}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  );
};

export default Button;
''';
    with open(components_dir / "Button.tsx", 'w') as f {
        f.write(button_tsx_content);
    }
    print("Created components/Button.tsx");

    readme_content = f'''  # {project_name}


A Jac client-side application with React and TypeScript support.

## Project Structure

```
{project_name}/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.tsx        # Example TypeScript component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac serve main.jac
```

## TypeScript Support

Create TypeScript components in `components/` and import them in your Jac files:

```jac
cl import from ".components/Button.tsx" {{ Button }}
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

    _create_gitignore(project_path, client=True);

    # Install default packages unless --skip is specified
    if not skip {
        print("\nInstalling default packages...");
        _install_default_packages(project_path, verbose);
    }

    print(f"\nProject '{project_name}' created successfully!");
    if name and name != cwd.name {
        print("\nNext steps:");
        print(f"  cd {name}");
        print("  jac serve main.jac");
    } else {
        print("\nNext steps:");
        print("  jac serve main.jac");
    }
}

"""Create .gitignore file with appropriate entries."""
def _create_gitignore(project_path: pathlib.Path, client: bool = False) -> None {
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
        "*.swp"
    ];

    if client {
        gitignore_entries.extend(
            [
                "",
                "# Node.js",
                "node_modules/",
                "",
                "# Jac build artifacts",
                ".jac/",
                "*.session",
                "*.session.*"
            ]
        );
    }

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
