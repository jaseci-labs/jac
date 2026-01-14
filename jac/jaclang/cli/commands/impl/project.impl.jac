"""Implementation of project commands.

Direct implementations - no delegation.
"""

import subprocess;
import shlex;
import sys;
import from pathlib { Path }

"""Initialize a new Jac project."""
impl create(name: str = '', force: bool = False) -> int {
    import from jaclang.project.config { JacConfig, find_project_root }
    cwd = Path.cwd();
    project_name = name or cwd.name;
    if name {
        project_path = cwd / name;
        if project_path.exists() and not force {
            print(
                f"Directory '{name}' already exists. Use --force to overwrite.",
                file=sys.stderr
            );
            return 1;
        }
        project_path.mkdir(parents=True, exist_ok=True);
    } else {
        project_path = cwd;
        existing = find_project_root(cwd);
        if existing and not force {
            (project_root, toml_path) = existing;
            print(f"Already in a Jac project: {toml_path}", file=sys.stderr);
            print("Use --force to reinitialize.", file=sys.stderr);
            return 1;
        }
    }
    toml_path = project_path / "jac.toml";
    if toml_path.exists() and not force {
        print(f"jac.toml already exists. Use --force to overwrite.", file=sys.stderr);
        return 1;
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
                f'"""Main entry point for {project_name}."""\n\nwith entry {{\n    print("Hello from {project_name}!");\n}}\n'
            );
        }
        print(f"Created {main_jac}");
    }
    # Create .jac directory with its own .gitignore to exclude build artifacts
    jac_dir = project_path / ".jac";
    jac_dir.mkdir(parents=True, exist_ok=True);
    jac_gitignore = jac_dir / ".gitignore";
    with open(jac_gitignore, "w") as f {
        f.write("# Ignore all build artifacts in .jac directory\n*\n");
    }
    print(f"Created {jac_gitignore}");
    try {
        result = subprocess.run(
            [sys.executable, "-m", "jaclang", "build", str(project_path / "main.jac")],
            capture_output=True,
            text=True,
            cwd=str(project_path)
        );
        if result.returncode == 0 {
            print("Pre-generated compiler cache");
        }
    } except Exception { }
    print(f"\nProject '{project_name}' initialized successfully!");
    print("\nNext steps:");
    if name {
        print(f"  cd {name}");
    }
    print("  jac run main.jac    # Run the main entry point");
    print("  jac add <package>   # Add dependencies");
    print("  jac install         # Install all dependencies");
    return 0;
}

"""Install all dependencies from jac.toml."""
impl install(dev: bool = False, verbose: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        return 1;
    }
    print(f"Installing dependencies for '{config.project.name}'...");
    print(f"Packages directory: {config.get_packages_dir()}");
    print();
    installer = DependencyInstaller(config=config, verbose=verbose);
    success = installer.install_all(include_dev=dev);
    if success {
        print("\nAll dependencies installed successfully!");
        return 0;
    } else {
        print("\nSome dependencies failed to install.", file=sys.stderr);
        return 1;
    }
}

"""Add dependencies to the project."""
impl add(
    packages: list = [],
    dev: bool = False,
    git: str = '',
    cl: bool = False,
    verbose: bool = False
) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller, DependencyResolver }
    config = get_config();
    if config is None {
        # If --cl flag is used, we need jac.toml to exist
        if cl {
            print(
                "No jac.toml found. Run 'jac init' to create a project.",
                file=sys.stderr
            );
            return 1;
        }
        # Skip silently if jac.toml doesn't exist (for regular Python deps)
        return 0;
    }
    if cl {
        import from jaclang.project.dep_registry { get_dependency_registry }
        registry = get_dependency_registry();
        dep_type = registry.get_by_flag("--cl");
        if dep_type is None {
            print(
                "Error: --cl flag requires jac-client plugin to be installed.",
                file=sys.stderr
            );
            print("Install with: pip install jac-client", file=sys.stderr);
            return 1;
        }
        if not packages {
            if dep_type.install_all_handler is None {
                print(
                    f"Error: No install_all handler registered for {dep_type.name}.",
                    file=sys.stderr
                );
                return 1;
            }
            try {
                print(f"Installing all {dep_type.name} packages from jac.toml...");
                dep_type.install_all_handler(config);
                print(f"\nInstalled all {dep_type.name} packages successfully.");
            } except Exception as e {
                print(f"Error installing packages: {e}", file=sys.stderr);
                return 1;
            }
            return 0;
        }
        try {
            resolver = DependencyResolver(config=config);
            for pkg_spec in packages {
                (name, version) = resolver.parse_spec(pkg_spec);
                print(f"Adding {name} ({dep_type.name})...");
                dep_type.install_handler(config, name, version, dev);
            }
            print(
                f"\nAdded {len(packages)} package(s) to [{(
                    'dependencies.' + dep_type.dev_name
                )
                if dev
                else ('dependencies.' + dep_type.name)}]"
            );
        } except Exception as e {
            print(f"Error installing packages: {e}", file=sys.stderr);
            return 1;
        }
        return 0;
    }
    # If no packages specified and not git, install all Python dependencies
    if not packages and not git {
        installer = DependencyInstaller(config=config, verbose=verbose);
        print("Installing all Python dependencies from jac.toml...");
        success = installer.install_all(include_dev=dev);
        if success {
            print("\nAll dependencies installed successfully!");
            return 0;
        } else {
            print("\nSome dependencies failed to install.", file=sys.stderr);
            return 1;
        }
    }
    installer = DependencyInstaller(config=config, verbose=verbose);
    resolver = DependencyResolver(config=config);
    if git {
        if packages {
            pkg_name = packages[0];
        } else {
            pkg_name = git.rstrip("/").split("/")[-1];
            if pkg_name.endswith(".git") {
                pkg_name = pkg_name[:-4];
            }
        }
        print(f"Adding {pkg_name} from git: {git}");
        config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
        if installer.install_git_package(pkg_name, git) {
            config.save();
            print(f"Added {pkg_name} from git");
            return 0;
        } else {
            return 1;
        }
    }
    for pkg_spec in packages {
        (name, version) = resolver.parse_spec(pkg_spec);
        version_str = version or ">=0.0.0";
        print(f"Adding {name}{version_str}...");
        if installer.install_package(name, version) {
            config.add_dependency(name, version_str, dev=dev, dep_type="python");
        } else {
            print(f"Failed to install {name}", file=sys.stderr);
            return 1;
        }
    }
    try {
        config.save();
        print("\nUpdated jac.toml");
    } except Exception as e {
        print(f"Warning: Could not save jac.toml: {e}", file=sys.stderr);
    }
    return 0;
}

"""Remove dependencies from the project."""
impl remove(packages: list = [], dev: bool = False, cl: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        return 1;
    }
    if not packages {
        print("No packages specified.", file=sys.stderr);
        return 1;
    }
    if cl {
        import from jaclang.project.dep_registry { get_dependency_registry }
        registry = get_dependency_registry();
        dep_type = registry.get_by_flag("--cl");
        if dep_type is None {
            print(
                "Error: --cl flag requires jac-client plugin to be installed.",
                file=sys.stderr
            );
            print("Install with: pip install jac-client", file=sys.stderr);
            return 1;
        }
        try {
            for name in packages {
                print(f"Removing {name} ({dep_type.name})...");
                dep_type.remove_handler(config, name, dev);
            }
            print(f"\nRemoved {len(packages)} package(s)");
        } except Exception as e {
            print(f"Error removing packages: {e}", file=sys.stderr);
            return 1;
        }
        return 0;
    }
    installer = DependencyInstaller(config=config);
    for name in packages {
        dep_type = "python";
        if name in config.git_dependencies {
            dep_type = "git";
        }
        if config.remove_dependency(name, dev=dev, dep_type=dep_type) {
            print(f"Removed {name} from jac.toml");
            installer.uninstall_package(name);
        } else {
            print(f"Package {name} not found in dependencies", file=sys.stderr);
        }
    }
    try {
        config.save();
        print("\nUpdated jac.toml");
    } except Exception as e {
        print(f"Warning: Could not save jac.toml: {e}", file=sys.stderr);
    }
    return 0;
}

"""Run custom scripts defined in jac.toml."""
impl script(name: str = '', list_scripts: bool = False) -> int {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        return 1;
    }
    if list_scripts or not name {
        if not config.scripts {
            print("No scripts defined in jac.toml.");
            print("\nTo add scripts, add a [scripts] section to your jac.toml:");
            print('  [scripts]');
            print('  dev = "jac run main.jac"');
            print('  test = "jac test"');
            return 0;
        }
        print("Available scripts:");
        for (script_name, script_cmd) in sorted(config.scripts.items()) {
            print(f"  {script_name}: {script_cmd}");
        }
        return 0;
    }
    if name not in config.scripts {
        print(f"Script '{name}' not found in jac.toml.", file=sys.stderr);
        print("\nAvailable scripts:");
        for script_name in sorted(config.scripts.keys()) {
            print(f"  {script_name}");
        }
        return 1;
    }
    script_cmd = config.scripts[name];
    print(f"Running: {script_cmd}");
    print();
    try {
        result = subprocess.run(
            script_cmd,
            shell=True,
            cwd=str(config.project_root) if config.project_root else None
        );
        return result.returncode;
    } except Exception as e {
        print(f"Error running script: {e}", file=sys.stderr);
        return 1;
    }
}
