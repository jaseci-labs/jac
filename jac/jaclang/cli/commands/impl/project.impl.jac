import os;
import sys;
import shutil;
import subprocess;
import tempfile;
import shlex;
import base64;
import importlib.metadata;
import from pathlib { Path }
import from jaclang.cli.console { console }

impl create(
    name: str = '',
    force: bool = False,
    kind: str = "",
    use: str = "default",
    list_jacpacks: bool = False
) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.template_registry {
        get_template_registry,
        initialize_template_registry
    }
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import from jaclang.project.kinds {
        is_valid_kind,
        kind_required_plugin,
        VALID_KINDS
    }
    registry = get_template_registry();

    if registry.is_empty() {
        initialize_template_registry();
    }

    if list_jacpacks {
        kinds = registry.list_kinds();
        if kinds {
            console.print(
                "\nProject kinds (jac create --kind <kind>):\n", style="info"
            );
            for (kname, desc) in kinds {
                plugin = kind_required_plugin(kname);
                suffix = f"  [needs {plugin}]" if plugin else "";
                console.print(f"  {kname}: {desc}{suffix}");
            }
        }
        variants = [
            (tname, desc)
            for (tname, desc) in registry.list_templates()
            if not is_valid_kind(tname)
        ];
        if variants {
            console.print(
                "\nNamed variants (jac create --use <name>):\n", style="info"
            );
            for (tname, desc) in variants {
                console.print(f"  {tname}: {desc}");
            }
        }
        if not kinds and not variants {
            console.info("No project templates available.");
        }
        return 0;
    }

    explicit_use = use != "default";
    if kind and explicit_use {
        console.error(
            "Use either --kind or --use, not both.",
            hint="--kind <kind> scaffolds a built-in kind; --use <path|url> a custom template."
        );
        return 1;
    }
    if explicit_use {
        tmpl = _resolve_template(use, registry);
        if tmpl is None {
            console.error(f"Unknown template: {use}");
            console.print(
                "Use --list_jacpacks to see available kinds and templates.",
                style="muted"
            );
            return 1;
        }
    } else {
        target_kind = kind or "cli";
        if not is_valid_kind(target_kind) {
            console.error(
                f"Unknown project kind '{target_kind}'.",
                hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
            );
            return 1;
        }
        plugin = kind_required_plugin(target_kind);
        if plugin and not _plugin_available(plugin) {
            console.error(
                f"Project kind '{target_kind}' requires the {plugin} plugin, which is not installed.",
                hint=f"Install it (e.g. `pip install {plugin}` / `jac add {plugin}`), then retry."
            );
            return 1;
        }
        tmpl = registry.get_by_kind(target_kind);
        if tmpl is None {
            console.error(
                f"No template registered for kind '{target_kind}'.",
                hint=(
                    f"The {plugin} plugin provides it -- ensure it is installed."
                        if plugin
                        else "This is unexpected for a core kind; please report it."
                )
            );
            return 1;
        }
    }
    cwd = Path.cwd();
    create_subdir = bool(name);
    if create_subdir {
        project_name = name;
    } else {
        project_name = _project_name_from_cwd(cwd);
        if not project_name {
            console.error(
                "Cannot infer a project name from the current directory.",
                hint="Run from a named directory or pass a project name: jac create myapp"
            );
            return 1;
        }
    }

    if create_subdir {
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

    for dir_path in tmpl.directories {
        (project_path / dir_path).mkdir(parents=True, exist_ok=True);
    }
    import time;
    start_time = time.time();
    console.print("\n✨ Creating new Jac project...\n", style="bold cyan");
    console.print("  📁 Setting up project structure", style="muted");

    import copy;
    render_config = copy.deepcopy(tmpl.config);
    _stamp_kind(render_config, tmpl.kind);

    toml_content = _render_config_to_toml(render_config, project_name);
    with open(toml_path, "w", encoding="utf-8") as f {
        f.write(toml_content);
    }
    console.print(f"  ✔ jac.toml", style="success");

    for (file_path, content) in tmpl.files.items() {
        full_path = project_path / file_path;
        full_path.parent.mkdir(parents=True, exist_ok=True);
        if not full_path.exists() or force {
            if content.startswith("base64:") {
                binary_data = base64.b64decode(content[7:]);
                with open(full_path, "wb") as f {
                    f.write(binary_data);
                }
            } else {
                rendered = content.replace("{{name}}", project_name);
                with open(full_path, "w", encoding="utf-8") as f {
                    f.write(rendered);
                }
            }
            console.print(f"  ✔ {file_path}", style="success");
        }
    }

    if _seed_agent_guide(project_path, force) {
        console.print(f"  ✔ AGENTS.md", style="success");
    }

    if tmpl.root_gitignore_entries {
        _create_root_gitignore(project_path, tmpl.root_gitignore_entries);
    }

    if tmpl.post_create is not None {
        try {
            tmpl.post_create(project_path, project_name);
        } except Exception as e {
            console.warning(f"Post-create hook failed: {e}");
        }
    }

    elapsed_time = time.time() - start_time;
    console.print();
    if elapsed_time < 1 {
        console.success(
            f"Project '{project_name}' created in {elapsed_time * 1000:.0f}ms"
        );
    } else {
        console.success(f"Project '{project_name}' created in {elapsed_time:.1f}s");
    }

    steps = [];
    if create_subdir {
        steps.append(f"cd {name}");
    }
    steps.append("jac install           Install dependencies");
    steps.append(f"jac run               {_run_blurb(tmpl.kind)}");
    console.print_next_steps(steps);
    console.print("\n🚀 Happy coding!\n", style="bold green");
    return 0;
}

def _run_blurb(kind: str) -> str {
    import from jaclang.project.kinds { VALID_KINDS }
    blurbs: dict[str, str] = {
        "cli": "Execute the project",
        "cli-native": "Native-compile and run",
        "native-binary": "Build a native binary into dist/",
        "native-lib": "Build a shared library",
        "service": "Serve the headless API",
        "service-mesh": "Serve the microservice",
        "py-package": "Build a wheel into dist/",
        "js-package": "Build an npm package into dist/",
        "web-app": "Serve the app (dev mode)",
        "web-static": "Serve the client-only app (static)",
        "desktop": "Run the desktop app",
        "mobile": "Build the mobile app"
    };

    assert set(blurbs.keys()) >= set(VALID_KINDS) , (
        f"_run_blurb missing kinds: {set(VALID_KINDS) - set(blurbs.keys())}"
    );
    return blurbs.get(kind, "Run the project");
}

def _stamp_kind(config: dict, kind: str) -> None {
    if not kind {
        return;
    }
    proj = config.get("project");
    if not isinstance(proj, dict) {
        proj = {};
        config["project"] = proj;
    }
    if not proj.get("kind") {
        proj["kind"] = kind;
    }
}

def _plugin_available(pkg: str) -> bool {
    import importlib.util;
    try {
        return importlib.util.find_spec(pkg.replace("-", "_")) is not None;
    } except (ImportError, ValueError) {
        return False;
    }
}

def _seed_agent_guide(project_path: Path, force: bool) -> bool {
    agents_path = project_path / "AGENTS.md";
    if agents_path.exists() and not force {
        return False;
    }
    content = """# Working in this Jac project

This is a [Jac](https://www.jaseci.org/) project. Jac's syntax has evolved and
is easily confused with Python or JSX -- before writing or editing `.jac`
files, consult the reference guides bundled with the compiler.

## Reference guides

The `jac` CLI ships curated reference guides ("Agent Skills") -- the
authoritative spec for writing correct, idiomatic Jac:

- `jac guide` -- list every available guide
- `jac guide <name>` -- print a guide (e.g. `jac guide jac-types`)
- `jac guide --search <keyword>` -- find guides by topic
- `jac guide --json` -- machine-readable output for tooling

Start with `jac guide jac-core-cheatsheet` and `jac guide jac-types`.

## Validate your work

- `jac check <file>` -- type-check and lint. Compiler diagnostics link to the
  relevant guide; follow the `-> run 'jac guide ...'` hints.
- `jac run <file>` -- execute a Jac script.
- `jac start --dev main.jac` -- start a web-app or service in dev mode
  (hot-reload for client files; restart for server changes). Use this instead
  of `jac run` for apps.
- `jac browse <action>` -- QA a running app in a headless browser:
  `jac browse open localhost:8000`, then `snapshot` (accessibility tree with
  `@e1`-style refs), `click @e5`, `fill '#email' user@example.com`, `screenshot`, `close`.

_Generated by `jac create`._
""";
    with open(agents_path, "w", encoding="utf-8") as f {
        f.write(content);
    }
    return True;
}

def _project_name_from_cwd(cwd: Path) -> str {
    return cwd.resolve().name;
}

def _resolve_template(use: str, registry: any) -> any {
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import tempfile;
    import urllib.request;
    import urllib.error;

    if use.startswith("http://") or use.startswith("https://") {
        console.print(f"Downloading template from {use}...");
        try {
            with tempfile.NamedTemporaryFile(suffix=".jacpack", delete=False) as tmp {
                tmp_path = Path(tmp.name);
            }
            urllib.request.urlretrieve(use, tmp_path);
            tmpl = load_template_from_json(tmp_path);

            tmp_path.unlink();
            console.print(f"Using template '{tmpl.name}' from URL");
            return tmpl;
        } except urllib.error.URLError as e {
            console.error(f"Error downloading template from URL: {e}");
            return None;
        } except Exception as e {
            console.error(f"Error loading template from URL: {e}");
            return None;
        }
    }

    use_path = Path(use);
    if use_path.exists() {
        try {
            if use_path.is_file() {
                if use_path.suffix == ".jacpack" or use.endswith(".jacpack") {
                    tmpl = load_template_from_json(use_path);
                    console.print(f"Using template '{tmpl.name}' from {use_path}");
                    return tmpl;
                } else {
                    console.error(f"Error: File must be a .jacpack file: {use}");
                    return None;
                }
            } elif use_path.is_dir() {
                tmpl = load_template_from_directory(use_path);
                console.print(f"Using template '{tmpl.name}' from {use_path}");
                return tmpl;
            }
        } except Exception as e {
            console.error(f"Error loading template from {use}: {e}");
            return None;
        }
    }

    if "/" in use or use.endswith(".jacpack") {
        console.error(f"Error: Template file or directory not found: {use}");
        return None;
    }

    tmpl = registry.get(use);
    if tmpl is None {
        console.error(f"Unknown jacpack template: {use}");
        console.error("Use --list_jacpacks to see available templates.");
        console.error("You can also specify a path to a .jacpack file or a URL.");
        return None;
    }
    return tmpl;
}

def _quote_toml_key(k: str) -> str {
    stripped: str = k.replace('_', '').replace('-', '');
    if stripped.isalnum() and len(k) > 0 {
        return k;
    }
    return f'"{k}"';
}

def _render_config_to_toml(config: dict, project_name: str) -> str {
    lines: list[str] = [];

    def render_value(v: any) -> str {
        if isinstance(v, str) {
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

    def render_section(section_name: str, section_data: dict, indent: str = "") {
        simple_values: dict = {};
        nested_sections: dict = {};

        for (k, v) in section_data.items() {
            if isinstance(v, dict) {
                nested_sections[k] = v;
            } else {
                simple_values[k] = v;
            }
        }

        if section_name {
            lines.append(f"[{section_name}]");
        }

        for (k, v) in simple_values.items() {
            lines.append(f"{_quote_toml_key(k)} = {render_value(v)}");
        }

        if simple_values and nested_sections {
            lines.append("");
        }

        for (k, v) in nested_sections.items() {
            nested_name = f"{section_name}.{k}" if section_name else k;
            render_section(nested_name, v);
            lines.append("");
        }
    }

    for (section, data) in config.items() {
        if isinstance(data, dict) {
            render_section(section, data);
            lines.append("");
        } else {
            lines.append(f"{section} = {render_value(data)}");
        }
    }

    while lines and lines[-1] == "" {
        lines.pop();
    }
    lines.append("");

    return "\n".join(lines);
}

def _create_root_gitignore(project_path: Path, entries: list[str]) {
    gitignore_path = project_path / ".gitignore";
    with open(gitignore_path, "w", encoding="utf-8") as f {
        f.write("\n".join(entries) + "\n");
    }
    console.print(f"  ✔ .gitignore", style="success");
}

impl install(
    packages: list = [],
    editable: list = [],
    dev: bool = False,
    extras: list = [],
    verbose: bool = False,
    force_reinstall: bool = False,
    no_cache_dir: bool = False,
    pre: bool = False,
    dry_run: bool = False,
    no_deps: bool = False,
    quiet: bool = False,
    prefer_binary: bool = False,
    install_global: bool = False,
    scale: bool = False
) -> int {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies {
        DependencyInstaller,
        get_venv_site_packages,
        capability_specs_for_install
    }
    import from jaclang.project.dep_registry { get_dependency_registry }

    flag_defs: list = [
        (force_reinstall, "--force-reinstall"),
        (no_cache_dir, "--no-cache-dir"),
        (pre, "--pre"),
        (dry_run, "--dry-run"),
        (no_deps, "--no-deps"),
        (quiet, "--quiet"),
        (prefer_binary, "--prefer-binary"),

    ];
    install_flags: list[str] = [
        flag
        for (enabled, flag) in flag_defs
        if enabled
    ];

    if packages {
        if editable {
            console.error(
                "Cannot mix package names with -e/--editable in a single command. "
                "Run them separately: 'jac install <pkg>' then 'jac install -e <path>'."
            );
            return 1;
        }
        if dev or extras {
            console.warning(
                "--dev and --extras have no effect with package names. "
                "Use 'jac add <pkg> --dev' to track packages in jac.toml."
            );
        }
        if install_global {
            console.print(
                f"\n📦 Installing {len(packages)} package(s) into the global site",
                style="bold"
            );
            cmd: list[str] = [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--upgrade"
            ] + install_flags + packages;
            if verbose {
                console.print(f"  Running: {' '.join(cmd)}", style="muted");
            }
            result = subprocess.run(cmd, capture_output=not verbose, text=True);
            if result.returncode != 0 {
                console.error(
                    f"Install failed:\n{result.stderr
                    or result.stdout
                    or '(see output above)'}"
                );
                return 1;
            }
            if dry_run {
                if result.stdout {
                    console.print(result.stdout, style="dim");
                }
                console.success("Dry run complete (nothing installed).");
                return 0;
            }
            console.success("Package(s) installed into the global site");
            return 0;
        }
        config = get_config();
        if config is None {
            console.error(
                "No jac.toml found",
                hint="Run 'jac create' first; packages install into the project's .jac/venv (or pass --global)."
            );
            return 1;
        }
        installer = DependencyInstaller(
            config=config, verbose=verbose, install_flags=install_flags
        );
        console.print(
            f"\n📦 Installing {len(packages)} package(s) into {config.get_venv_dir()}",
            style="bold"
        );
        return 0 if installer.install_package(packages) else 1;
    }

    editable = [p for group in (editable or []) for p in group];
    if editable {
        import from jaclang.publish.builder { WheelBuilder }

        editable_targets: list = [];
        all_dep_specs: list[str] = [];
        for editable_path in editable {
            src_dir: Path = Path(editable_path).resolve();
            if not src_dir.is_dir() {
                console.error(
                    f"'{editable_path}' is not a directory.",
                    hint=f"Use 'jac install {editable_path}' to install from PyPI, or pass a local path to -e."
                );
                return 1;
            }
            config = get_config(start_path=src_dir, force_discover=True);
            if config is None {
                console.error(
                    "No jac.toml found",
                    hint=f"Make sure {src_dir} contains a jac.toml."
                );
                return 1;
            }
            specs_installer = DependencyInstaller(
                config=config, verbose=verbose, install_flags=install_flags
            );
            dep_specs = specs_installer.get_pip_package_specs(include_dev=dev);
            if extras {
                try {
                    extra_specs = specs_installer.get_extra_package_specs(extras);
                    if extra_specs {
                        dep_specs.extend(extra_specs);
                    }
                } except ValueError as e {
                    console.warning(
                        f"  Skipping extras for {config.project.name}: {e}"
                    );
                }
            }
            all_dep_specs.extend(dep_specs);
            editable_targets.append((config, src_dir));
            console.print(
                f"\n📦 Editable: {config.project.name} ({src_dir})", style="bold"
            );
        }

        if install_global {
            if all_dep_specs {
                console.print(
                    f"\n  Installing {len(
                        all_dep_specs
                    )} dependencies into the global site...",
                    style="muted"
                );
                result = subprocess.run(
                    [
                        sys.executable,
                        "-m",
                        "pip",
                        "install",
                        "--upgrade"
                    ] + install_flags + all_dep_specs,
                    capture_output=not verbose,
                    text=True,
                );
                if result.returncode != 0 {
                    console.error(
                        f"Dependency install failed:\n{result.stderr or result.stdout}"
                    );
                    return 1;
                }
            }
            if dry_run {
                console.print(
                    "  ✔ Dry run complete (nothing installed).", style="success"
                );
                return 0;
            }
            import site;
            site_pkgs = Path(site.getsitepackages()[0]);
        } else {
            host_config = get_config(force_discover=True);
            if host_config is None {
                console.error(
                    "No jac.toml found",
                    hint="Run 'jac create' first; `jac install -e` links into the current project's .jac/venv (or pass --global)."
                );
                return 1;
            }
            host_installer = DependencyInstaller(
                config=host_config, verbose=verbose, install_flags=install_flags
            );
            if all_dep_specs {
                console.print(
                    f"\n  Installing {len(all_dep_specs)} dependencies into {host_config.get_venv_dir()}...",
                    style="muted"
                );
                if not host_installer.install_package(all_dep_specs) {
                    return 1;
                }
            }
            if dry_run {
                console.print(
                    "  ✔ Dry run complete (nothing installed).", style="success"
                );
                return 0;
            }
            host_installer.ensure_venv();
            site_pkgs = get_venv_site_packages(host_config.get_venv_dir());
        }

        for (config, src_dir) in editable_targets {
            WheelBuilder(config=config).install_editable(src_dir, site_pkgs);
            console.print(f"  ✔ Linked {src_dir}", style="success");
        }
        console.print("  ✔ Editable install complete.", style="success");
        return 0;
    }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    installer = DependencyInstaller(
        config=config, verbose=verbose, install_flags=install_flags
    );
    console.print(
        f"\n📦 Installing dependencies for {config.project.name}", style="bold"
    );
    console.print(f"  Virtual environment: {config.get_venv_dir()}", style="muted");
    console.print();
    pip_packages = installer.get_pip_package_specs(include_dev=dev);
    git_packages = installer.get_git_package_specs();
    if extras {
        try {
            extra_specs = installer.get_extra_package_specs(extras);
        } except ValueError as e {
            console.error(str(e));
            return 1;
        }
        if extra_specs {
            console.print(f"  Extras: {', '.join(extras)}", style="muted");
        }
        pip_packages.extend(extra_specs);
    }

    cap_specs = capability_specs_for_install(config, installer, scale);
    if cap_specs {
        pip_packages.extend(cap_specs);
    }

    dep_registry = get_dependency_registry();
    plugin_types = dep_registry.get_all();
    has_plugin_deps = False;
    for type_name in plugin_types.keys() {
        if config.get_plugin_deps(type_name) {
            has_plugin_deps = True;
            break;
        }
    }
    if not pip_packages and not git_packages and not has_plugin_deps {
        console.info("No dependencies to install.");
        return 0;
    }

    install_success = True;
    all_packages = pip_packages + git_packages;
    if all_packages {
        with console.status(
            f"Installing {len(all_packages)} package(s)...", spinner="dots"
        ) as status {
            install_success = installer.install_package(all_packages);
        }
    }

    if dry_run {
        return 0 if install_success else 1;
    }
    plugin_failed = False;
    for (type_name, dep_type) in plugin_types.items() {
        plugin_deps = config.get_plugin_deps(type_name);
        if not plugin_deps {
            continue;
        }
        console.print(f"\n  Installing {type_name} dependencies...", style="muted");
        if dep_type.install_all_handler is not None {
            try {
                dep_type.install_all_handler(config);
                console.print(
                    f"  ✔ {type_name} dependencies installed", style="success"
                );
            } except Exception as e {
                console.error(f"  ✗ {type_name} dependencies failed: {e}");
                plugin_failed = True;
            }
        } else {
            for (dep_name, dep_version) in plugin_deps.items() {
                try {
                    dep_type.install_handler(config, dep_name, dep_version, False);
                    console.print(f"  ✔ {dep_name}", style="success");
                } except Exception as e {
                    console.error(f"  ✗ {dep_name}: {e}");
                    plugin_failed = True;
                }
            }
        }
    }
    if install_success and not plugin_failed {
        console.success("All dependencies installed");
        return 0;
    } else {
        console.error("Some dependencies failed to install");
        return 1;
    }
}

impl add(
    packages: list = [], dev: bool = False, git: str = '', verbose: bool = False
) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller, DependencyResolver }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    if not packages and not git {
        console.error(
            "No packages specified",
            hint="Use 'jac add <package>' to add a package, or 'jac install' to install all dependencies."
        );
        return 1;
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
        console.print(f"\n📦 Adding {pkg_name} from git", style="bold");
        console.print(f"  Repository: {git}", style="muted");
        with console.status(f"Installing {pkg_name}...", spinner="dots") as status {
            specs = installer._make_git_spec(pkg_name, git);
            git_success = installer.install_package([specs]);
        }
        if git_success {
            config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
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
        if version {
            install_spec = installer._make_pip_spec(name, version);
        } else {
            install_spec = name;
        }
        with console.status(f"Installing {name}...", spinner="dots") as status {
            pkg_success = installer.install_package([install_spec]);
        }
        if pkg_success {
            if not version {
                installed_version = installer.get_installed_version(name);
                if installed_version {
                    version_str = f"~={_major_minor(installed_version)}";
                    if verbose {
                        console.print(
                            f"Detected version: {installed_version}", style="muted"
                        );
                    }
                } else {
                    version_str = ">=0.0.0";
                    if verbose {
                        console.warning(
                            f"Could not detect version for {name}, using >=0.0.0"
                        );
                    }
                }
            } else {
                version_str = version;
            }
            config.add_dependency(name, version_str, dev=dev, dep_type="python");
            console.print(f"  ✔ {name} ({version_str})", style="success");
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
        return 1;
    }
    return 0;
}

impl remove(packages: list = [], dev: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return 1;
    }
    if not packages {
        console.error("No packages specified.");
        return 1;
    }
    installer = DependencyInstaller(config=config);
    for name in packages {
        dep_type = "python";
        is_dev = dev;
        if name in config.git_dependencies {
            dep_type = "git";
        } elif not dev
        and name not in config.dependencies
        and name in config.dev_dependencies {
            is_dev = True;
        }
        if config.remove_dependency(name, dev=is_dev, dep_type=dep_type) {
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
        console.error(f"Could not save jac.toml: {e}");
        return 1;
    }
    return 0;
}

def _major_minor(version: str) -> str {
    parts = version.split(".");
    if len(parts) >= 2 {
        return f"{parts[0]}.{parts[1]}";
    }
    return version;
}

impl update(packages: list = [], dev: bool = False, verbose: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller, DependencyResolver }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    installer = DependencyInstaller(config=config, verbose=verbose);
    resolver = DependencyResolver(config=config);

    specs_to_update: list[str] = [];
    names_to_update: list[str] = [];
    if packages {
        for pkg_spec in packages {
            (name, version) = resolver.parse_spec(pkg_spec);
            if name in config.dependencies {
                specs_to_update.append(name);
                names_to_update.append(name);
            } elif name in config.dev_dependencies {
                specs_to_update.append(name);
                names_to_update.append(name);
            } elif name in config.git_dependencies {
                git_info = config.git_dependencies[name];
                if isinstance(git_info, dict) and "git" in git_info {
                    specs_to_update.append(
                        installer._make_git_spec(
                            name, git_info["git"], git_info.get("branch", "")
                        )
                    );
                    names_to_update.append(name);
                }
            } else {
                console.error(f"Package '{name}' not found in dependencies.");
                return 1;
            }
        }
    } else {
        for (name, version) in config.dependencies.items() {
            specs_to_update.append(name);
            names_to_update.append(name);
        }
        if dev {
            for (name, version) in config.dev_dependencies.items() {
                specs_to_update.append(name);
                names_to_update.append(name);
            }
        }
        git_specs = installer.get_git_package_specs();
        for spec in git_specs {
            specs_to_update.append(spec);
        }
        for name in config.git_dependencies.keys() {
            names_to_update.append(name);
        }
    }
    if not specs_to_update {
        console.info("No dependencies to update.");
        return 0;
    }
    console.print(
        f"\n📦 Updating {len(specs_to_update)} package(s) for {config.project.name}",
        style="bold"
    );
    with console.status(
        f"Updating {len(specs_to_update)} package(s)...", spinner="dots"
    ) as status {
        update_success = installer.install_package(specs_to_update);
    }
    if not update_success {
        console.error("Some packages failed to update.");
        return 1;
    }

    updated_count = 0;
    for name in names_to_update {
        if name in config.git_dependencies {
            continue;
        }
        installed_version = installer.get_installed_version(name);
        if installed_version {
            new_spec = f"~={_major_minor(installed_version)}";

            current_spec = config.dependencies.get(
                name, config.dev_dependencies.get(name, "")
            );
            if current_spec.startswith("~=") or not current_spec {
                if name in config.dependencies {
                    config.dependencies[name] = new_spec;
                    updated_count += 1;
                } elif name in config.dev_dependencies {
                    config.dev_dependencies[name] = new_spec;
                    updated_count += 1;
                }
                console.print(
                    f"  ✔ {name} -> {installed_version} ({new_spec})", style="success"
                );
            } else {
                console.print(
                    f"  ✔ {name} -> {installed_version} (spec unchanged: {current_spec})",
                    style="success"
                );
            }
        }
    }
    if updated_count > 0 {
        try {
            config.save();
            console.print(
                f"\n  ✔ Updated {updated_count} version(s) in jac.toml", style="muted"
            );
        } except Exception as e {
            console.error(f"Could not save jac.toml: {e}");
            return 1;
        }
    }
    console.success("Dependencies updated");
    return 0;
}

impl script(name: str = '', list_scripts: bool = False) -> int {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found. Run 'jac create <name>' to create a project."
        );
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
            console.print('  dev = "jac start main.jac"', style="muted");
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
        console.error(
            "No jac.toml found. Run 'jac create <name>' to create a project."
        );
        return 1;
    }

    dirs_to_clean: list[tuple[str, Path]] = [];

    if all {
        dirs_to_clean.append(("data", config.get_data_dir()));
        dirs_to_clean.append(("cache", config.get_cache_dir()));
        dirs_to_clean.append(("venv", config.get_venv_dir()));
        dirs_to_clean.append(("client", config.get_client_dir()));
    } else {
        if data {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
        if cache {
            dirs_to_clean.append(("cache", config.get_cache_dir()));
        }
        if packages {
            dirs_to_clean.append(("venv", config.get_venv_dir()));
        }
        if not dirs_to_clean {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
    }

    existing_dirs = [
        (name, path)
        for (name, path) in dirs_to_clean
        if path.exists()
    ];
    if not existing_dirs {
        console.info("Nothing to clean - no build artifact directories exist.");
        return 0;
    }

    console.print("\nThe following directories will be removed:\n", style="warning");
    for (name, path) in existing_dirs {
        console.print(f"  {name}: {path}", style="muted");
    }
    console.print();

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

impl jacpack(action: str = "", path: str = "", output: str = "") -> int {
    import from jaclang.project.template_registry { get_template_registry }
    import from jaclang.project.template_loader {
        load_template_from_directory,
        load_template_from_json,
        bundle_template
    }
    if not action or action == "list" {
        registry = get_template_registry();
        templates = registry.list_templates();
        if not templates {
            console.print("No templates available.");
            return 0;
        }
        console.print("Available templates:");
        for (tname, desc) in templates {
            console.print(f"  {tname}: {desc}");
        }
        return 0;
    }
    if action == "pack" {
        if not path {
            console.error("Error: Template directory path required.");
            console.print("Usage: jac jacpack pack <directory> [-o output.jacpack]");
            return 1;
        }
        template_dir = Path(path);
        if not template_dir.is_dir() {
            console.error(f"Error: Not a directory: {template_dir}");
            return 1;
        }

        if output {
            output_path = Path(output);
        } else {
            jac_toml_path = template_dir / "jac.toml";
            if jac_toml_path.exists() {
                import from jaclang.jac0core.helpers { read_toml_with_encoding }
                jac_config = read_toml_with_encoding(str(jac_toml_path));
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
            console.error(f"Error bundling template: {e}");
            return 1;
        }
    }
    if action == "info" {
        if not path {
            console.error("Error: Template path required.");
            console.print("Usage: jac jacpack info <path>");
            return 1;
        }
        template_path = Path(path);
        try {
            if template_path.is_dir() {
                tmpl = load_template_from_directory(template_path);
            } elif template_path.suffix == ".json" {
                tmpl = load_template_from_json(template_path);
            } else {
                console.error(f"Error: Unknown template format: {path}");
                return 1;
            }

            console.print(f"Template: {tmpl.name}");
            console.print(f"Description: {tmpl.description}");
            console.print(f"Files: {len(tmpl.files)}");
            for file_path in sorted(tmpl.files.keys()) {
                console.print(f"  - {file_path}");
            }
            console.print(f"Directories: {tmpl.directories}");
            if tmpl.post_create is not None {
                console.print("Post-create hook: Yes");
            }
            return 0;
        } except Exception as e {
            console.error(f"Error loading template: {e}");
            return 1;
        }
    }
    console.error(f"Unknown action: {action}");
    console.print("Available actions: list, pack, info");
    return 1;
}

def _bundle_wheel(config: any, output: str) -> int {
    import from jaclang.publish.builder { WheelBuilder }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    builder = WheelBuilder(config=config, project_root=config.project_root);

    console.print("\n  Transpiling Jac → Python and building wheel...", style="muted");
    try {
        whl_path = builder.build_to(out_dir);
    } except Exception as e {
        console.error(f"Wheel build failed: {e}");
        return 1;
    }
    if builder.skipped_codespace {
        console.print(
            f"  ⚠ skipped {len(builder.skipped_codespace)} client/native "
            "codespace file(s) (.cl.jac/.na.jac) — not part of a Python wheel",
            style="warning"
        );
    }
    if builder.vendored_runtime_modules {
        console.print(
            f"  ✔ vendored jac runtime ({builder.vendored_runtime_modules} modules) "
            "— wheel runs without jaclang installed",
            style="success"
        );
    }
    console.print(
        f"  ✔ Built {whl_path.name} ({whl_path.stat().st_size:,} bytes)",
        style="success"
    );

    console.print("  Building sdist...", style="muted");
    try {
        sdist_path = builder.build_sdist_to(out_dir);
    } except Exception as e {
        console.error(f"Sdist build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ {sdist_path.name} ({sdist_path.stat().st_size:,} bytes)", style="success"
    );

    console.print(
        f"\n  Distributions written to: [cyan]{out_dir}[/cyan]", style="bold"
    );
    console.print("  Upload with: twine upload dist/*", style="muted");
    return 0;
}

def _bundle_npm(config: any, output: str) -> int {
    import from jaclang.publish.npm_builder { NpmBuilder }
    import from jaclang.publish.npm_sources { NpmBoundaryError }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    console.print("\n  Building npm tarball...", style="muted");
    try {
        builder = NpmBuilder(config=config, project_root=config.project_root);
        tgz_path = builder.build_to(out_dir);
    } except NpmBoundaryError as e {
        console.error(f"npm build failed: {e}");
        return 1;
    } except Exception as e {
        console.error(f"npm build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ Built {tgz_path.name} ({tgz_path.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Tarball written to: {tgz_path}", style="cyan");
    console.print("  Publish with: npm publish", style="muted");
    return 0;
}

def _bundle_npm_runtime(output: str, framework: str = "") -> int {
    import from jaclang.publish.runtime_npm { build_runtime_to, runtime_pkg_name }
    import importlib.metadata;

    version = importlib.metadata.version("jaclang");
    pkg_name = runtime_pkg_name(framework);
    out_dir = Path(output);
    console.print(f"\n📦 Building {pkg_name} v{version}", style="bold");
    console.print("\n  Compiling runtime → npm tarball...", style="muted");
    try {
        path = build_runtime_to(out_dir, version, framework=framework);
    } except Exception as e {
        console.error(f"runtime build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ Built {path.name} ({path.stat().st_size:,} bytes)", style="success"
    );
    console.print(f"  Tarball written to: {path}", style="cyan");
    console.print("  Publish with: npm publish", style="muted");
    return 0;
}

impl bundle(output: str = "dist", target: str = "wheel") -> int {
    import from jaclang.project.config { get_config }

    if target == "npm-runtime" {
        return _bundle_npm_runtime(output);
    }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return 1;
    }
    if config.project.name is None {
        console.error(
            "No project name in jac.toml",
            hint="Add 'name' under [project] to use jac bundle."
        );
        return 1;
    }
    if target not in ("wheel", "npm", "all") {
        console.error(
            f"Unknown bundle target: '{target}'",
            hint="Use --target wheel, npm, or all."
        );
        return 1;
    }

    console.print(
        f"\n📦 Bundling {config.project.name} " f"v{config.project.version} ({target})",
        style="bold"
    );

    if target in ("wheel", "all") {
        if _bundle_wheel(config, output) != 0 {
            return 1;
        }
    }
    if target in ("npm", "all") {
        if _bundle_npm(config, output) != 0 {
            return 1;
        }
    }
    return 0;
}
