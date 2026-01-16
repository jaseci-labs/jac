"""Implementation of project commands.

Direct implementations - no delegation.
"""

import subprocess;
import shlex;
import sys;
import from pathlib { Path }

"""Initialize a new Jac project."""
impl create(
    name: str = '',
    force: bool = False,
    template: str = "default",
    list_templates: bool = False
) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.template_registry { get_template_registry }
    registry = get_template_registry();
    # Handle --list-templates
    if list_templates {
        templates = registry.list_templates();
        if not templates {
            print("No templates available.");
            return 0;
        }
        print("Available templates:");
        for (tname, desc) in templates {
            print(f"  {tname}: {desc}");
        }
        return 0;
    }
    # Get template
    tmpl = registry.get(template);
    if tmpl is None {
        print(f"Unknown template: {template}", file=sys.stderr);
        print("Use --list-templates to see available templates.", file=sys.stderr);
        return 1;
    }
    cwd = Path.cwd();
    project_name = name or cwd.name;
    # Validate/create project directory
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
    # Create directories from template
    for dir_path in tmpl.directories {
        (project_path / dir_path).mkdir(parents=True, exist_ok=True);
    }
    # Generate jac.toml from config dict
    toml_content = _render_config_to_toml(tmpl.config, project_name);
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    print(f"Created {toml_path}");
    # Generate files from template
    for (file_path, content) in tmpl.files.items() {
        rendered = content.replace("{{name}}", project_name);
        full_path = project_path / file_path;
        full_path.parent.mkdir(parents=True, exist_ok=True);
        if not full_path.exists() or force {
            with open(full_path, "w") as f {
                f.write(rendered);
            }
            print(f"Created {full_path}");
        }
    }
    # Create .gitignore files from template
    if tmpl.gitignore_entries {
        _create_jac_gitignore(project_path, tmpl.gitignore_entries);
    }
    if tmpl.root_gitignore_entries {
        _create_root_gitignore(project_path, tmpl.root_gitignore_entries);
    }
    # Pre-generate compiler cache if main.jac exists
    main_jac = project_path / "main.jac";
    if main_jac.exists() {
        try {
            result = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", str(main_jac)],
                capture_output=True,
                text=True,
                cwd=str(project_path)
            );
            if result.returncode == 0 {
                print("Pre-generated compiler cache");
            }
        } except Exception { }
    }
    # Run post-create hook if defined
    if tmpl.post_create is not None {
        try {
            tmpl.post_create(project_path, project_name);
        } except Exception as e {
            print(f"Warning: post-create hook failed: {e}", file=sys.stderr);
        }
    }
    print(f"\nProject '{project_name}' created successfully!");
    print("\nNext steps:");
    if name {
        print(f"  cd {name}");
    }
    print("  jac run main.jac    # Run the main entry point");
    print("  jac add <package>   # Add dependencies");
    print("  jac install         # Install all dependencies");
    return 0;
}

"""Quote TOML key if it contains special characters."""
def _quote_toml_key(k: str) -> str {
    # TOML bare keys can only contain A-Za-z0-9_-
    stripped: str = k.replace('_', '').replace('-', '');
    if stripped.isalnum() and len(k) > 0 {
        return k;
    }
    return f'"{k}"';
}

"""Render a config dict to TOML format."""
def _render_config_to_toml(config: dict, project_name: str) -> str {
    lines: list[str] = [];

    def render_value(v: any) -> str {
        if isinstance(v, str) {
            # Replace {{name}} placeholder and escape for TOML
            v = v.replace("{{name}}", project_name);
            return f'"{v}"';
        } elif isinstance(v, bool) {
            return "true" if v else "false";
        } elif isinstance(v, (int, float)) {
            return str(v);
        } elif isinstance(v, list) {
            items = [render_value(item) for item in v];
            return "[" + ", ".join(items) + "]";
        } else {
            return str(v);
        }
    }

    def render_section(section_name: str, section_data: dict, indent: str = "") -> None {
        # Separate simple values from nested dicts
        simple_values: dict = {};
        nested_sections: dict = {};

        for (k, v) in section_data.items() {
            if isinstance(v, dict) {
                nested_sections[k] = v;
            } else {
                simple_values[k] = v;
            }
        }

        # Write section header
        if section_name {
            lines.append(f"[{section_name}]");
        }

        # Write simple values
        for (k, v) in simple_values.items() {
            lines.append(f"{_quote_toml_key(k)} = {render_value(v)}");
        }

        if simple_values and nested_sections {
            lines.append("");
        }

        # Write nested sections
        for (k, v) in nested_sections.items() {
            nested_name = f"{section_name}.{k}" if section_name else k;
            render_section(nested_name, v);
            lines.append("");
        }
    }

    # Render top-level sections
    for (section, data) in config.items() {
        if isinstance(data, dict) {
            render_section(section, data);
            lines.append("");
        } else {
            lines.append(f"{section} = {render_value(data)}");
        }
    }

    # Clean up trailing newlines
    while lines and lines[-1] == "" {
        lines.pop();
    }
    lines.append("");

    return "\n".join(lines);
}

"""Create .jac/.gitignore with entries."""
def _create_jac_gitignore(project_path: Path, entries: list[str]) -> None {
    jac_dir = project_path / ".jac";
    if jac_dir.exists() {
        jac_gitignore = jac_dir / ".gitignore";
        with open(jac_gitignore, "w") as f {
            f.write("\n".join(entries) + "\n");
        }
        print(f"Created {jac_gitignore}");
    }
}

"""Create project-root .gitignore with entries."""
def _create_root_gitignore(project_path: Path, entries: list[str]) -> None {
    gitignore_path = project_path / ".gitignore";
    with open(gitignore_path, "w") as f {
        f.write("\n".join(entries) + "\n");
    }
    print(f"Created {gitignore_path}");
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

"""Clean project build artifacts."""
impl clean(
    all: bool = False,
    data: bool = False,
    cache: bool = False,
    packages: bool = False,
    force: bool = False
) -> int {
    import shutil;
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        return 1;
    }
    # Determine which directories to clean
    dirs_to_clean: list[tuple[str, Path]] = [];
    # If --all is specified, clean everything
    if all {
        dirs_to_clean.append(("data", config.get_data_dir()));
        dirs_to_clean.append(("cache", config.get_cache_dir()));
        dirs_to_clean.append(("packages", config.get_packages_dir()));
        dirs_to_clean.append(("client", config.get_client_dir()));
    } else {
        # If specific flags are set, use them
        if data {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
        if cache {
            dirs_to_clean.append(("cache", config.get_cache_dir()));
        }
        if packages {
            dirs_to_clean.append(("packages", config.get_packages_dir()));
        }
        # If no specific flags, default to cleaning data directory
        if not dirs_to_clean {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
    }
    # Filter to only existing directories
    existing_dirs = [
        (name, path)
        for (name, path) in dirs_to_clean
        if path.exists()
    ];
    if not existing_dirs {
        print("Nothing to clean - no build artifact directories exist.");
        return 0;
    }
    # Show what will be cleaned
    print("The following directories will be removed:");
    for (name, path) in existing_dirs {
        print(f"  {name}: {path}");
    }
    print();
    # Confirm unless --force is used
    if not force {
        try {
            response = input("Continue? [y/N] ").strip().lower();
            if response not in ["y", "yes"] {
                print("Aborted.");
                return 0;
            }
        } except (EOFError, KeyboardInterrupt) {
            print("\nAborted.");
            return 0;
        }
    }
    # Remove the directories
    errors = 0;
    for (name, path) in existing_dirs {
        try {
            shutil.rmtree(path);
            print(f"Removed {name}: {path}");
        } except Exception as e {
            print(f"Error removing {name} ({path}): {e}", file=sys.stderr);
            errors += 1;
        }
    }
    if errors > 0 {
        print(f"\nCompleted with {errors} error(s).", file=sys.stderr);
        return 1;
    }
    print("\nClean completed successfully.");
    return 0;
}
