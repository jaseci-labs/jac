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
    existing = find_project_root(cwd);
    if existing and not force {
        (project_root, toml_path) = existing;
        print(f"Already in a Jac project: {toml_path}", file=sys.stderr);
        print("Use --force to reinitialize.", file=sys.stderr);
        <>exit(1);
    }

    project_name = name or cwd.name;

    toml_path = cwd / "jac.toml";
    if toml_path.exists() and not force {
        print("jac.toml already exists. Use --force to overwrite.", file=sys.stderr);
        <>exit(1);
    }

    toml_content = JacConfig.create_default_toml(project_name);
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    print(f"Created {toml_path}");

    main_jac = cwd / f"{name}.jac";
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

    packages_dir = cwd / "packages";
    if not packages_dir.exists() {
        packages_dir.mkdir(parents=True, exist_ok=True);
        print(f"Created {packages_dir}/");
    }

    _create_gitignore(cwd, client=False);

    print(f"\nProject '{project_name}' initialized successfully!");
    print("\nNext steps:");
    print("  jac run main.jac    # Run the main entry point");
    print("  jac add <package>   # Add dependencies");
    print("  jac install         # Install all dependencies");
}

"""Prompt user to select project starter type."""
def _prompt_starter_type() -> str {
    """Show interactive prompt for starter type selection with arrow key navigation.
    
    Returns:
        'plain' or 'fullstack' based on user selection
    """;
    try {
        import questionary;
        choice = questionary.select(
            "Select starter type:",
            choices=[
                questionary.Choice("Plain starter (basic React app)", "plain"),
                questionary.Choice("Fullstack starter (with auth & router)", "fullstack")
            ],
            default="plain"
        ).ask();
        return choice if choice else "plain";
    } except KeyboardInterrupt {
        print("\nCancelled.", file=sys.stderr);
        <>exit(1);
    } except Exception as e {
        # If questionary fails for any reason, provide helpful error
        print(
            f"Error: Interactive prompt unavailable ({e}). Please install questionary: pip install questionary",
            file=sys.stderr
        );
        <>exit(1);
    }
}

"""Scaffold project from template in examples folder."""
def _scaffold_from_template(
    project_path: pathlib.Path,
    project_name: str,
    template_name: str
) -> None {
    """Copy template files from examples folder to project directory.
    
    Args:
        project_path: Target project directory
        project_name: Name of the project
        template_name: Name of the template to use (e.g., 'plain-starter', 'basic-auth-with-router')
    """;
    # Get the template directory relative to jac_client package
    # The examples directory is at jac_client/examples/
    # This file is at jac_client/plugin/cli.jac
    # So we go up one level from plugin to jac_client, then into examples
    template_dir: pathlib.Path | None = None;
    try {
        # Try relative to this file's location
        plugin_dir = pathlib.Path(__file__).parent;
        template_dir = plugin_dir.parent / "examples" / template_name;
        if not template_dir.exists() {
            # Fallback: try to find jac_client in Python path
            import sys;
            for path_str in sys.path {
                path = pathlib.Path(path_str);
                candidate = path / "jac_client" / "examples" / template_name;
                if candidate.exists() {
                    template_dir = candidate;
                    break;
                }
            }
        }
    } except Exception as e {
        raise RuntimeError(f"Could not locate template directory: {e}") from e;
    }
    
    if template_dir is None or not template_dir.exists() {
        raise RuntimeError(f"Template '{template_name}' not found. Searched at: {template_dir if template_dir else 'unknown'}");
    }
    
    # Copy template files
    for item in template_dir.rglob("*") {
        if item.is_dir() {
            continue;
        }
        
        # Skip .gitignore and other hidden/system files
        if item.name.startswith('.') and item.name != '.gitignore' {
            continue;
        }
        
        # Calculate relative path from template directory
        rel_path = item.relative_to(template_dir);
        target_path = project_path / rel_path;
        
        # Create parent directories
        target_path.parent.mkdir(parents=True, exist_ok=True);
        
        # Copy file
        shutil.copy2(item, target_path);
        
        # Update project name in jac.toml and README.md
        if item.name == "jac.toml" {
            with open(target_path, 'r') as f {
                content = f.read();
            }
            # Replace template name with project name
            content = content.replace(f'name = "{template_name}"', f'name = "{project_name}"');
            content = content.replace(
                f'description = "Jac client application: {template_name}"',
                f'description = "Jac client application: {project_name}"'
            );
            with open(target_path, 'w') as f {
                f.write(content);
            }
        } elif item.name == "README.md" {
            with open(target_path, 'r') as f {
                content = f.read();
            }
            # Replace template name with project name in README
            content = content.replace(template_name, project_name);
            with open(target_path, 'w') as f {
                f.write(content);
            }
        }
        
        print(f"Created {rel_path}");
    }
    
    # Ensure .jac/client directory exists
    (project_path / ".jac" / "client").mkdir(parents=True, exist_ok=True);
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

    # Prompt user for starter type
    starter_type = _prompt_starter_type();
    
    print(f"Creating Jac client application: {project_name}");

    if starter_type == "fullstack" {
        # Scaffold from fullstack template
        _scaffold_from_template(project_path, project_name, "basic-auth-with-router");
    } else {
        # Scaffold from plain starter template
        _scaffold_from_template(project_path, project_name, "plain-starter");
    }

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
        print("  jac serve src/app.jac");
    } else {
        print("\nNext steps:");
        print("  jac serve src/app.jac");
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
