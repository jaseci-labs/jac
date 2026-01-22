"""Implementation of project commands.

Direct implementations - no delegation.
"""

import subprocess;
import shlex;
import sys;
import base64;
import from pathlib { Path }

"""Initialize a new Jac project."""
impl create(
    name: str = '',
    force: bool = False,
    use: str = "default",
    list_jacpacks: bool = False
) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.template_registry { get_template_registry }
    import from jaclang.cli.console { console }
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    registry = get_template_registry();
    # Handle --list-jacpacks
    if list_jacpacks {
        templates = registry.list_templates();
        if not templates {
            console.info("No jacpack templates available.");
            return 0;
        }
        console.print("\nAvailable templates:\n", style="info");
        for (tname, desc) in templates {
            console.print(f"  {tname}: {desc}");
        }
        return 0;
    }
    # If no name specified, use "jactastic" as default with incrementing number if exists
    if not name {
        name = _generate_default_project_name(Path.cwd());
    }
    # Resolve template from --use (supports: registered names, file paths, URLs)
    tmpl = _resolve_template(use, registry);
    if tmpl is None {
        console.error(f"Unknown template: {template}");
        console.print(
            "Use --list-templates to see available templates.", style="muted"
        );
        return 1;
    }
    cwd = Path.cwd();
    project_name = name;
    # Validate/create project directory
    if name {
        project_path = cwd / name;
        if project_path.exists() and not force {
            console.error(
                f"Directory '{name}' already exists. Use --force to overwrite."
            );
            return 1;
        }
        project_path.mkdir(parents=True, exist_ok=True);
    } else {
        project_path = cwd;
        existing = find_project_root(cwd);
        if existing and not force {
            (project_root, toml_path) = existing;
            console.error(f"Already in a Jac project: {toml_path}");
            console.print("Use --force to reinitialize.", style="muted");
            return 1;
        }
    }
    project_path.mkdir(parents=True, exist_ok=True);
    toml_path = project_path / "jac.toml";
    if toml_path.exists() and not force {
        console.error("jac.toml already exists. Use --force to overwrite.");
        return 1;
    }
    # Create directories from template
    for dir_path in tmpl.directories {
        (project_path / dir_path).mkdir(parents=True, exist_ok=True);
    }
    import time;
    start_time = time.time();
    console.print("\n✨ Creating new Jac project...\n", style="bold cyan");
    console.print("  📁 Setting up project structure", style="muted");
    # Generate jac.toml from config dict
    toml_content = _render_config_to_toml(tmpl.config, project_name);
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    console.print(f"  ✔ jac.toml", style="success");
    # Generate files from template
    for (file_path, content) in tmpl.files.items() {
        full_path = project_path / file_path;
        full_path.parent.mkdir(parents=True, exist_ok=True);
        if not full_path.exists() or force {
            # Check if content is base64-encoded binary (prefixed with "base64:")
            if content.startswith("base64:") {
                # Decode binary content and write as bytes
                binary_data = base64.b64decode(content[7:]);
                with open(full_path, "wb") as f {
                    f.write(binary_data);
                }
            } else {
                # Text file - apply template substitution and write as text
                rendered = content.replace("{{name}}", project_name);
                with open(full_path, "w") as f {
                    f.write(rendered);
                }
            }
            console.print(f"  ✔ {file_path}", style="success");
        }
    }
    # Create .gitignore files from template
    if tmpl.gitignore_entries {
        _create_jac_gitignore(project_path, tmpl.gitignore_entries);
    }
    if tmpl.root_gitignore_entries {
        _create_root_gitignore(project_path, tmpl.root_gitignore_entries);
    }
    # Run post-create hook if defined
    if tmpl.post_create is not None {
        try {
            # Post-create hook output will be shown by the hook itself
            tmpl.post_create(project_path, project_name);
        } except Exception as e {
            console.warning(f"Post-create hook failed: {e}");
        }
    }
    # Calculate elapsed time
    elapsed_time = time.time() - start_time;
    console.print();
    if elapsed_time < 1 {
        console.success(
            f"Project '{project_name}' created in {elapsed_time * 1000:.0f}ms"
        );
    } else {
        console.success(f"Project '{project_name}' created in {elapsed_time:.1f}s");
    }
    # Print next steps in a nice box
    steps = [];
    if name {
        steps.append(f"cd {name}");
    }
    steps.append("jac install         Install dependencies");
    steps.append("jac run main.jac    Start development");
    console.print_next_steps(steps);
    console.print("\n🚀 Happy coding!\n", style="bold green");
    return 0;
}

"""Generate a default project name using 'jactastic' with incrementing number if needed."""
def _generate_default_project_name(cwd: Path) -> str {
    base_name = "jactastic";
    # If jactastic doesn't exist, use it
    if not (cwd / base_name).exists() {
        return base_name;
    }
    # Otherwise, find the next available number
    n = 1;
    while (cwd / f"{base_name}{n}").exists() {
        n += 1;
    }
    return f"{base_name}{n}";
}

"""Resolve a template from a name, file path, or URL.

Supports:
- Registered template names (e.g., "default", "client")
- Local file paths to .jacpack files (e.g., "./my-template.jacpack")
- Local directory paths with jac.toml [jacpack] section (e.g., "./my-template/")
- URLs to .jacpack files (e.g., "https://example.com/template.jacpack")

Returns the ProjectTemplate or None if resolution fails.
"""
def _resolve_template(use: str, registry: any) -> any {
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import tempfile;
    import urllib.request;
    import urllib.error;

    # Check if it's a URL
    if use.startswith("http://") or use.startswith("https://") {
        print(f"Downloading template from {use}...");
        try {
            # Download to a temporary file
            with tempfile.NamedTemporaryFile(suffix=".jacpack", delete=False) as tmp {
                tmp_path = Path(tmp.name);
            }
            urllib.request.urlretrieve(use, tmp_path);
            tmpl = load_template_from_json(tmp_path);
            # Clean up temp file
            tmp_path.unlink();
            print(f"Using template '{tmpl.name}' from URL");
            return tmpl;
        } except urllib.error.URLError as e {
            print(f"Error downloading template from URL: {e}", file=sys.stderr);
            return None;
        } except Exception as e {
            print(f"Error loading template from URL: {e}", file=sys.stderr);
            return None;
        }
    }

    # Check if it's a local file path
    use_path = Path(use);
    if use_path.exists() {
        try {
            if use_path.is_file() {
                # Load from .jacpack file
                if use_path.suffix == ".jacpack" or use.endswith(".jacpack") {
                    tmpl = load_template_from_json(use_path);
                    print(f"Using template '{tmpl.name}' from {use_path}");
                    return tmpl;
                } else {
                    print(
                        f"Error: File must be a .jacpack file: {use}", file=sys.stderr
                    );
                    return None;
                }
            } elif use_path.is_dir() {
                # Load from directory with jac.toml [jacpack] section
                tmpl = load_template_from_directory(use_path);
                print(f"Using template '{tmpl.name}' from {use_path}");
                return tmpl;
            }
        } except Exception as e {
            print(f"Error loading template from {use}: {e}", file=sys.stderr);
            return None;
        }
    }

    # Check if path looks like a file path but doesn't exist
    if "/" in use or use.endswith(".jacpack") {
        print(f"Error: Template file or directory not found: {use}", file=sys.stderr);
        return None;
    }

    # Fall back to registry lookup
    tmpl = registry.get(use);
    if tmpl is None {
        print(f"Unknown jacpack template: {use}", file=sys.stderr);
        print("Use --list-jacpacks to see available templates.", file=sys.stderr);
        print(
            "You can also specify a path to a .jacpack file or a URL.", file=sys.stderr
        );
        return None;
    }
    return tmpl;
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
    import from jaclang.cli.console { console }
    jac_dir = project_path / ".jac";
    if jac_dir.exists() {
        jac_gitignore = jac_dir / ".gitignore";
        with open(jac_gitignore, "w") as f {
            f.write("\n".join(entries) + "\n");
        }
        console.print(f"  ✔ .jac/.gitignore", style="success");
    }
}

"""Create project-root .gitignore with entries."""
def _create_root_gitignore(project_path: Path, entries: list[str]) -> None {
    import from jaclang.cli.console { console }
    gitignore_path = project_path / ".gitignore";
    with open(gitignore_path, "w") as f {
        f.write("\n".join(entries) + "\n");
    }
    console.print(f"  ✔ .gitignore", style="success");
}

"""Install all dependencies from jac.toml."""
impl install(dev: bool = False, verbose: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    import from jaclang.cli.console { console }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return 1;
    }
    console.print(
        f"\n📦 Installing dependencies for [cyan]{config.project.name}[/cyan]",
        style="bold"
    );
    console.print(f"  Packages directory: {config.get_packages_dir()}", style="muted");
    console.print();
    installer = DependencyInstaller(config=config, verbose=verbose);
    with console.status("[cyan]Installing packages...[/cyan]", spinner="dots") as status {
        install_success = installer.install_all(include_dev=dev);
    }
    if install_success {
        console.success("All dependencies installed");
        return 0;
    } else {
        console.error("Some dependencies failed to install");
        return 1;
    }
}

"""Add dependencies to the project."""
impl add(
    packages: list = [], dev: bool = False, git: str = '', verbose: bool = False
) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller, DependencyResolver }
    import from jaclang.cli.console { console }
    config = get_config();
    if config is None {
        # Skip silently if jac.toml doesn't exist (for regular Python deps)
        return 0;
    }
    # If no packages specified and not git, install all Python dependencies
    if not packages and not git {
        installer = DependencyInstaller(config=config, verbose=verbose);
        console.print(
            "\n📦 Installing all Python dependencies from jac.toml", style="bold"
        );
        with console.status(
            "[cyan]Installing Python packages...[/cyan]", spinner="dots"
        ) as status {
            install_success = installer.install_all(include_dev=dev);
        }
        if install_success {
            console.success("All dependencies installed");
            return 0;
        } else {
            console.error("Some dependencies failed to install");
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
        console.print(f"\n📦 Adding [cyan]{pkg_name}[/cyan] from git", style="bold");
        console.print(f"  Repository: {git}", style="muted");
        config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
        with console.status(f"[cyan]Installing {pkg_name}...[/cyan]", spinner="dots") as status {
            git_success = installer.install_git_package(pkg_name, git);
        }
        if git_success {
            config.save();
            console.print(f"  ✔ {pkg_name}", style="success");
            console.print(f"\n  ✔ Updated jac.toml [dependencies.git]", style="muted");
            return 0;
        } else {
            console.error(f"Failed to install {pkg_name}");
            return 1;
        }
    }
    console.print(f"\n📦 Adding {len(packages)} Python package(s)", style="bold");
    for pkg_spec in packages {
        (name, version) = resolver.parse_spec(pkg_spec);
        version_str = version or ">=0.0.0";
        with console.status(f"[cyan]Installing {name}...[/cyan]", spinner="dots") as status {
            pkg_success = installer.install_package(name, version);
        }
        if pkg_success {
            config.add_dependency(name, version_str, dev=dev, dep_type="python");
            console.print(f"  ✔ {name}", style="success");
        } else {
            console.error(f"Failed to install {name}");
            return 1;
        }
    }
    try {
        config.save();
        section = "dev-dependencies" if dev else "dependencies";
        console.print(f"\n  ✔ Updated jac.toml [{section}]", style="muted");
    } except Exception as e {
        console.error(f"Could not save jac.toml: {e}");
    }
    return 0;
}

"""Remove dependencies from the project."""
impl remove(packages: list = [], dev: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    import from jaclang.cli.console { console }
    config = get_config();
    if config is None {
        console.error("No jac.toml found. Run 'jac init' to create a project.");
        return 1;
    }
    if not packages {
        console.error("No packages specified.");
        return 1;
    }
    installer = DependencyInstaller(config=config);
    for name in packages {
        dep_type = "python";
        if name in config.git_dependencies {
            dep_type = "git";
        }
        if config.remove_dependency(name, dev=dev, dep_type=dep_type) {
            console.success(f"Removed {name} from jac.toml");
            installer.uninstall_package(name);
        } else {
            console.error(f"Package {name} not found in dependencies");
        }
    }
    try {
        config.save();
        console.success("Updated jac.toml");
    } except Exception as e {
        console.warning(f"Could not save jac.toml: {e}");
    }
    return 0;
}

"""Run custom scripts defined in jac.toml."""
impl script(name: str = '', list_scripts: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    config = get_config();
    if config is None {
        console.error("No jac.toml found. Run 'jac init' to create a project.");
        return 1;
    }
    if list_scripts or not name {
        if not config.scripts {
            console.info("No scripts defined in jac.toml.");
            console.print(
                "\nTo add scripts, add a [scripts] section to your jac.toml:",
                style="muted"
            );
            console.print('  [scripts]', style="muted");
            console.print('  dev = "jac run main.jac"', style="muted");
            console.print('  test = "jac test"', style="muted");
            return 0;
        }
        console.print("\nAvailable scripts:\n", style="info");
        for (script_name, script_cmd) in sorted(config.scripts.items()) {
            console.print(f"  {script_name}: {script_cmd}");
        }
        return 0;
    }
    if name not in config.scripts {
        console.error(f"Script '{name}' not found in jac.toml.");
        console.print("\nAvailable scripts:", style="muted");
        for script_name in sorted(config.scripts.keys()) {
            console.print(f"  {script_name}", style="muted");
        }
        return 1;
    }
    script_cmd = config.scripts[name];
    console.info(f"Running: {script_cmd}");
    console.print();
    try {
        result = subprocess.run(
            script_cmd,
            shell=True,
            cwd=str(config.project_root) if config.project_root else None
        );
        return result.returncode;
    } except Exception as e {
        console.error(f"Error running script: {e}");
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
    import from jaclang.cli.console { console }
    config = get_config();
    if config is None {
        console.error("No jac.toml found. Run 'jac init' to create a project.");
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
        console.info("Nothing to clean - no build artifact directories exist.");
        return 0;
    }
    # Show what will be cleaned
    console.print("\nThe following directories will be removed:\n", style="warning");
    for (name, path) in existing_dirs {
        console.print(f"  {name}: {path}", style="muted");
    }
    console.print();
    # Confirm unless --force is used
    if not force {
        try {
            response = input("Continue? [y/N] ").strip().lower();
            if response not in ["y", "yes"] {
                console.info("Aborted.");
                return 0;
            }
        } except (EOFError, KeyboardInterrupt) {
            console.print("\nAborted.", style="info");
            return 0;
        }
    }
    # Remove the directories
    errors = 0;
    for (name, path) in existing_dirs {
        try {
            shutil.rmtree(path);
            console.success(f"Removed {name}: {path}");
        } except Exception as e {
            console.error(f"Error removing {name} ({path}): {e}");
            errors += 1;
        }
    }
    if errors > 0 {
        console.error(f"Completed with {errors} error(s).");
        return 1;
    }
    console.success("Clean completed successfully.");
    return 0;
}

"""Manage project templates (.jacpack files)."""
impl jacpack(action: str = "", path: str = "", output: str = "") -> int {
    import from jaclang.project.template_registry { get_template_registry }
    import from jaclang.project.template_loader {
        load_template_from_directory,
        load_template_from_json,
        bundle_template
    }
    if not action or action == "list" {
        # List available templates
        registry = get_template_registry();
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
    if action == "pack" {
        if not path {
            print("Error: Template directory path required.", file=sys.stderr);
            print("Usage: jac jacpack pack <directory> [-o output.jacpack]");
            return 1;
        }
        template_dir = Path(path);
        if not template_dir.is_dir() {
            print(f"Error: Not a directory: {template_dir}", file=sys.stderr);
            return 1;
        }
        # Determine output path
        if output {
            output_path = Path(output);
        } else {
            # Default to <template-name>.jacpack in current directory
            jac_toml_path = template_dir / "jac.toml";
            if jac_toml_path.exists() {
                import tomllib;
                with open(jac_toml_path, "rb") as f {
                    jac_config = tomllib.load(f);
                }
                name = jac_config.get("jacpack", {}).get("name", template_dir.name);
            } else {
                name = template_dir.name;
            }
            output_path = Path.cwd() / f"{name}.jacpack";
        }
        try {
            bundle_template(template_dir, output_path);
            return 0;
        } except Exception as e {
            print(f"Error bundling template: {e}", file=sys.stderr);
            return 1;
        }
    }
    if action == "info" {
        if not path {
            print("Error: Template path required.", file=sys.stderr);
            print("Usage: jac jacpack info <path>");
            return 1;
        }
        template_path = Path(path);
        try {
            if template_path.is_dir() {
                tmpl = load_template_from_directory(template_path);
            } elif template_path.suffix == ".json" {
                tmpl = load_template_from_json(template_path);
            } else {
                print(f"Error: Unknown template format: {path}", file=sys.stderr);
                return 1;
            }

            # Access strongly-typed ProjectTemplate fields
            print(f"Template: {tmpl.name}");
            print(f"Description: {tmpl.description}");
            print(f"Files: {len(tmpl.files)}");
            for file_path in sorted(tmpl.files.keys()) {
                print(f"  - {file_path}");
            }
            print(f"Directories: {tmpl.directories}");
            if tmpl.post_create is not None {
                print("Post-create hook: Yes");
            }
            return 0;
        } except Exception as e {
            print(f"Error loading template: {e}", file=sys.stderr);
            return 1;
        }
    }
    print(f"Unknown action: {action}", file=sys.stderr);
    print("Available actions: list, pack, info");
    return 1;
}
