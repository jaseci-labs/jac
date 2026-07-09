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
    list_jacpacks: bool = False,
    pack: str = "",
    pack_output: str = "",
    `skip: bool = False,
    style: str | None = None,
    baseColor: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menuAccent: str | None = None,
    menuColor: str | None = None
) -> int {
    if pack {
        return jacpack(action="pack", path=pack, output=pack_output);
    }
    if `skip {
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }
    if use == "jac-shadcn" {
        import from jaclang.cli.shadcn.cli { stash_create_theme }
        theme_args = {
            "style": style,
            "baseColor": baseColor,
            "theme": theme,
            "font": font,
            "radius": radius,
            "menuAccent": menuAccent,
            "menuColor": menuColor
        };
        overrides = {
            k: v
            for (k, v) in theme_args.items()
            if v is not None
        };
        stash_create_theme(overrides);
    }
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
    scale: bool = False,
    plan: bool = False,
    as_json: bool = False
) -> int {
    if plan {
        return deps(scale=scale, as_json=as_json);
    }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { ensure_venv, get_venv_site_packages }
    import from jaclang.project.providers {
        InstallContext,
        get_provider_registry,
        get_python_provider,
        resolve_plan
    }

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
    python = get_python_provider();
    ctx = InstallContext(verbose=verbose, install_flags=install_flags);
    global_ctx = InstallContext(
        verbose=verbose, install_flags=install_flags, target="global"
    );

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
            if not python.install_specs(None, packages, global_ctx) {
                return 1;
            }
            if dry_run {
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
        console.print(
            f"\n📦 Installing {len(packages)} package(s) into {config.get_venv_dir()}",
            style="bold"
        );
        return 0 if python.install_specs(config, packages, ctx) else 1;
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
            dep_specs = python.specs_for(
                [
                    d
                    for d in python.resolve(config, include_dev=dev)
                    if d.source == "pypi"
                ]
            );
            if extras {
                try {
                    extra_deps = python.resolve_extras(config, extras);
                    dep_specs.extend(python.specs_for(extra_deps));
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
                if not python.install_specs(None, all_dep_specs, global_ctx) {
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
            if all_dep_specs {
                console.print(
                    f"\n  Installing {len(all_dep_specs)} dependencies into {host_config.get_venv_dir()}...",
                    style="muted"
                );
                if not python.install_specs(host_config, all_dep_specs, ctx) {
                    return 1;
                }
            }
            if dry_run {
                console.print(
                    "  ✔ Dry run complete (nothing installed).", style="success"
                );
                return 0;
            }
            ensure_venv(host_config.get_venv_dir(), verbose);
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
    console.print(
        f"\n📦 Installing dependencies for {config.project.name}", style="bold"
    );
    console.print(f"  Virtual environment: {config.get_venv_dir()}", style="muted");
    console.print();
    try {
        plan = resolve_plan(config, include_dev=dev, extras=extras, scale=scale);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    if extras {
        console.print(f"  Extras: {', '.join(extras)}", style="muted");
    }
    if plan.is_empty() {
        console.info("No dependencies to install.");
        return 0;
    }

    install_success = True;
    python_deps = plan.for_ecosystem("python");
    if python_deps {
        with console.status(
            f"Installing {len(python_deps)} package(s)...", spinner="dots"
        ) as status {
            install_success = python.install_all(config, python_deps, ctx);
        }
    }

    if dry_run {
        return 0 if install_success else 1;
    }
    plugin_failed = False;
    for provider in get_provider_registry().all() {
        if provider.name == "python" {
            continue;
        }
        provider_deps = plan.for_ecosystem(provider.name);
        if not provider_deps {
            continue;
        }
        console.print(f"\n  Installing {provider.name} dependencies...", style="muted");
        try {
            provider.install_all(config, provider_deps, ctx);
            console.print(
                f"  ✔ {provider.name} dependencies installed", style="success"
            );
        } except Exception as e {
            console.error(f"  ✗ {provider.name} dependencies failed: {e}");
            plugin_failed = True;
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
    packages: list = [],
    dev: bool = False,
    git: str = '',
    verbose: bool = False,
    npm: bool = False,
    shadcn: bool = False
) -> int {
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_add }
        return run_shadcn_add(packages);
    }
    if npm {
        import from jaclang.runtimelib.client.cli { run_npm_add }
        return run_npm_add(packages, dev);
    }
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { make_git_spec }
    import from jaclang.project.providers { InstallContext, get_python_provider }
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
    python = get_python_provider();
    ctx = InstallContext(verbose=verbose);
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
            git_success = python.install_specs(config, [make_git_spec(git)], ctx);
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
        (name, version) = python.parse_spec(pkg_spec);
        with console.status(f"Installing {name}...", spinner="dots") as status {
            recorded = python.add_package(config, name, version, dev, ctx);
        }
        if recorded is None {
            console.error(f"Failed to install {name}");
            return 1;
        }
        console.print(f"  ✔ {name} ({recorded})", style="success");
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

impl remove(
    packages: list = [], dev: bool = False, npm: bool = False, shadcn: bool = False
) -> int {
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_remove }
        return run_shadcn_remove(packages);
    }
    if npm {
        import from jaclang.runtimelib.client.cli { run_npm_remove }
        return run_npm_remove(packages, dev);
    }
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { InstallContext, get_python_provider }
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
    python = get_python_provider();
    ctx = InstallContext();
    for name in packages {
        if python.remove_package(config, name, dev, ctx) {
            console.success(f"Removed {name} from jac.toml");
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
    import from jaclang.project.pyvenv { make_git_spec }
    import from jaclang.project.providers { InstallContext, get_python_provider }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    python = get_python_provider();
    ctx = InstallContext(verbose=verbose);

    specs_to_update: list[str] = [];
    names_to_update: list[str] = [];
    if packages {
        for pkg_spec in packages {
            (name, version) = python.parse_spec(pkg_spec);
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
                        make_git_spec(git_info["git"], git_info.get("branch", ""))
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
        for (name, git_info) in config.git_dependencies.items() {
            if isinstance(git_info, dict) and "git" in git_info {
                specs_to_update.append(
                    make_git_spec(git_info.get("git", ""), git_info.get("branch", ""))
                );
            }
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
        update_success = python.install_specs(config, specs_to_update, ctx);
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
        installed_version = python.get_installed_version(config, name);
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

impl deps(scale: bool = False, as_json: bool = False) -> int {
    import json;
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { resolve_plan }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    try {
        plan = resolve_plan(config, include_dev=True, scale=scale);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    if as_json {
        payload = [
            {
                "name": d.name,
                "version": d.version,
                "ecosystem": d.ecosystem,
                "source": d.source,
                "origin": d.origin,
                "dev": d.dev
            } for d in plan.deps
        ];
        console.print(json.dumps(payload, indent=2));
        return 0;
    }
    if plan.is_empty() {
        console.info("No dependencies resolved for this project.");
        return 0;
    }
    console.print(
        f"\n📦 Resolved dependency plan for {config.project.name}", style="bold"
    );
    for ecosystem in plan.ecosystems() {
        eco_deps = plan.for_ecosystem(ecosystem);
        console.print(f"\n  [{ecosystem}] ({len(eco_deps)})", style="info");
        width = max([len(d.name) for d in eco_deps]);
        for d in sorted(eco_deps, key=lambda d : (d.origin, d.name)) {
            dev_marker = "  (dev)" if d.dev else "";
            version = d.version or "*";
            console.print(
                f"    {d.name.ljust(width)}  {version}{dev_marker}  -- {d.origin}",
                style="muted"
            );
        }
    }
    console.print(
        f"\n  {len(plan.deps)} dependencies across "
        f"{len(plan.ecosystems())} ecosystem(s)",
        style="success"
    );
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
            console.print(
                "Usage: jac create --pack <directory> [--pack_output output.jacpack]"
            );
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

def _seal_copy_ignore(_dir: str, items: list) -> list {
    drop = [
        "__pycache__",
        "node_modules",
        ".jac",
        "_precompiled",
        ".git",
        ".venv",
        "venv",
        "dist",
        "build",
        ".mypy_cache",
        ".pytest_cache"
    ];
    return [
        it
        for it in items
        if it in drop or it.endswith("-seal-stage")
    ];
}

def _run_precompiler(src_dir: str, flags: list[str]) -> int {
    import sys;
    import subprocess;

    code = (
        "import _jac_finder as _jf; _jf.apply_dev_source_override(); _jf.install(); "
        "import sys; sys.argv = ['precompile', " + repr(src_dir) + "] + " + repr(
            list(flags)
        ) + "; from jaclang.utils.precompile_bytecode import main; main()"
    );
    return subprocess.call([sys.executable, "-c", code]);
}

def _resolve_entry_file(config: any) -> (Path | None) {
    ep = config.project.entry_point;
    proj_root = config.project_root;
    if not ep or proj_root is None {
        return None;
    }
    p = Path(proj_root) / ep;
    if p.is_file() {
        return p;
    }
    p2 = Path(str(p) + ".jac");
    if p2.is_file() {
        return p2;
    }
    console.print(
        f"  ⚠ [project] entry-point '{ep}' not found under {proj_root}; "
        "sealing without serve payloads",
        style="warning"
    );
    return None;
}

def _build_serve_manifest(entry_file: Path, proj_root: Path) -> (dict | None) {
    import os;
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.jac0core.compiler { get_boundary_analysis_sched }
    import from jaclang.runtimelib.client_bundle { _ensure_js_generated }
    import from jaclang.utils.precompile_bytecode {
        find_jac_files,
        _nested_project_dirs
    }

    nested = _nested_project_dirs(str(proj_root));
    targets = [
        p
        for p in find_jac_files(str(proj_root))
        if not any(p.startswith(n) for n in nested)
    ];
    entry_key = str(entry_file.resolve());
    if entry_key not in targets {
        targets.insert(0, entry_key);
    }

    for jac_path in targets {
        prev_errors = len(Jac.program.errors_had);
        try {
            Jac.program.compile(jac_path);
        } except Exception as e {
            console.error(f"Seal aborted: '{jac_path}' failed to compile: {e}");
            return None;
        }
        if len(Jac.program.errors_had) > prev_errors {
            errs = "\n".join(str(e) for e in Jac.program.errors_had[prev_errors:]);
            console.error(f"Seal aborted: '{jac_path}' failed to compile:\n{errs}");
            return None;
        }
    }

    client: dict = {};
    mod = Jac.program.find_module(entry_key);
    if mod and mod.gen.client_manifest {
        if not mod.gen.client_manifest.exports {
            _ensure_js_generated(mod, Jac.program);
        }
        m = mod.gen.client_manifest;
        client = {
            'exports': list(m.exports),
            'globals': list(m.globals),
            'params': m.params,
            'globals_values': m.globals_values,
            'has_client': m.has_client
        };
    }

    proj_prefix = str(proj_root.resolve()) + os.sep;

    def in_project(hmod: any) -> bool {
        mp = hmod?.loc?.mod_path;
        return bool(mp) and os.path.abspath(str(mp)).startswith(proj_prefix);
    }

    for hub in Jac.program._search_hubs() {
        for hmod in hub.values() {
            if not in_project(hmod) {
                continue;
            }
            man0 = hmod.gen.interop_manifest if (hmod and hmod.gen) else None;
            if man0 and not (man0.walker_access or man0.func_access) {
                try {
                    Jac.program.run_schedule(hmod, get_boundary_analysis_sched());
                } except Exception {
                    ;
                }
            }
        }
    }

    func_access: dict[str, bool] = {};
    walker_access: dict[str, bool] = {};
    endpoint_effects: dict[str, any] = {};
    cross: list[dict] = [];
    seen: set = set();
    for hub in Jac.program._search_hubs() {
        for hmod in hub.values() {
            if not in_project(hmod) {
                continue;
            }
            man = hmod.gen.interop_manifest if (hmod and hmod.gen) else None;
            if not man {
                continue;
            }
            for (n, a) in man.func_access.items() {
                if n not in func_access {
                    func_access[n] = a;
                }
            }
            for (n, a) in man.walker_access.items() {
                if n not in walker_access {
                    walker_access[n] = a;
                }
            }
            for (ekey, eeff) in man.endpoint_effects.items() {
                endpoint_effects[ekey] = eeff;
            }
            for binding in man.server_exports_to_client {
                ast_node = binding?.ast_node;
                src_path = (
                    ast_node.loc.mod_path if (ast_node and ast_node?.loc) else None
                );
                if not src_path or (binding.name, binding.kind) in seen {
                    continue;
                }
                try {
                    rel = os.path.relpath(src_path, str(proj_root));
                } except ValueError {
                    continue;
                }
                if rel.startswith('..') {
                    continue;
                }
                table = walker_access if binding.kind == 'walker' else func_access;
                auth = table.get(binding.name, None);
                if auth is None {
                    is_pub = (
                        ast_node is not None
                        and ast_node?.access is not None
                        and ast_node.access.tag.name == Tok.KW_PUB
                    );
                    auth = not is_pub;
                }
                seen.add((binding.name, binding.kind));
                cross.append(
                    {
                        'name': binding.name,
                        'kind': binding.kind,
                        'src': rel.replace(os.sep, '/'),
                        'auth': bool(auth)
                    }
                );
            }
        }
    }
    return {
        'client': client,
        'func_access': func_access,
        'walker_access': walker_access,
        'endpoint_effects': endpoint_effects,
        'cross_bindings': cross
    };
}

def _ensure_client_dist(config: any, entry_file: Path) -> (Path | None) {
    import from jaclang.runtimelib.client { get_bun }
    import from jaclang.runtimelib.client.targets.web_target { WebTarget }

    dist = config.get_client_dir() / 'dist';
    bun = None;
    try {
        bun = get_bun();
    } except Exception {
        bun = None;
    }
    if bun {
        console.print("  Building client bundle (web)...", style="muted");
        try {
            WebTarget().build(entry_file, Path(config.project_root));
        } except Exception as e {
            console.error(f"Client build failed: {e}");
            return None;
        }
        return dist if dist.is_dir() else None;
    }
    if dist.is_dir() and any(dist.glob('client.*.js')) {
        console.print(
            "  ⚠ bun unavailable; baking the existing client dist as-is",
            style="warning"
        );
        return dist;
    }
    console.error(
        "This app has client code but no client bundle could be built or "
        "found (.jac/client/dist).",
        hint="Install bun (jac will fetch it on demand) or prebuild the client."
    );
    return None;
}

def _bake_native_payloads(config: any, pkg_copy: Path) -> bool {
    import os;
    import from jaclang.jac0core.ext_registry { is_native_module, base_stem }
    import from jaclang.runtimelib.sealed_serve { NATIVE_DIR_REL }

    entry_file = _resolve_entry_file(config);
    if entry_file is None or not is_native_module(str(entry_file)) {
        return True;
    }
    try {
        import jaclang.compiler.passes.native.llvm.binding as llvm;
        triple = llvm.get_default_triple();
    } except Exception as e {
        console.error(f"Cannot resolve the native target triple: {e}");
        return False;
    }
    stem = base_stem(entry_file.name);
    out_dir = pkg_copy / NATIVE_DIR_REL / triple;
    out_dir.mkdir(parents=True, exist_ok=True);
    console.print(f"  Compiling native binary for {triple}...", style="muted");
    import from jaclang.cli.commands.nacompile { nacompile }
    rc = nacompile(filename=str(entry_file), output=str(out_dir / stem));
    if rc != 0 {
        console.error("Native compilation failed; seal aborted.");
        return False;
    }
    return True;
}

def _bake_serve_payloads(config: any, pkg_copy: Path) -> bool {
    import json;
    import shutil;
    import from jaclang.runtimelib.sealed_serve { SERVE_MANIFEST_REL, CLIENT_DIST_REL }

    entry_file = _resolve_entry_file(config);
    if entry_file is None {
        return True;
    }
    sm = _build_serve_manifest(entry_file, Path(config.project_root));
    if sm is None {
        return False;
    }
    dest_manifest = pkg_copy / SERVE_MANIFEST_REL;
    dest_manifest.parent.mkdir(parents=True, exist_ok=True);
    dest_manifest.write_text(
        json.dumps(sm, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );

    client_meta = sm.get('client', {}) or {};
    if not (client_meta.get('has_client') or client_meta.get('exports')) {
        return True;
    }
    dist_src = _ensure_client_dist(config, entry_file);
    if dist_src is None {
        return False;
    }
    dest_dist = pkg_copy / CLIENT_DIST_REL;
    if dest_dist.exists() {
        shutil.rmtree(dest_dist);
    }
    shutil.copytree(dist_src, dest_dist);
    n_files = sum(
        1
        for p in dest_dist.rglob('*')
        if p.is_file()
    );
    console.print(f"  ✔ Baked client dist ({n_files} files)", style="success");
    return True;
}

def _make_sealed_image(
    config: any, parent: Path, name: str, out_dir: (Path | None) = None
) -> (Path | None) {
    import shutil;
    import tempfile;
    import from jaclang.jac0core { ext_registry }

    proj_root = config.project_root;
    if proj_root is None {
        console.error("No project root to seal.");
        return None;
    }

    out_names: set = set();
    if out_dir is not None {
        try {
            rel0 = Path(out_dir).resolve().relative_to(Path(proj_root).resolve());
            out_names.add(rel0.parts[0]);
        } except ValueError { }
    }

    def copy_ignore(d: str, items: list) -> list {
        skipped = _seal_copy_ignore(d, items);
        if out_names and Path(d).resolve() == Path(proj_root).resolve() {
            skipped = list(
                set(skipped) | {
                    it
                    for it in items
                    if it in out_names
                }
            );
        }
        return skipped;
    }

    stage = Path(tempfile.mkdtemp(prefix=f"{name}-seal-"));
    try {
        pkg_copy = stage / name;
        shutil.copytree(proj_root, pkg_copy, ignore=copy_ignore);

        has_init = any((pkg_copy / f).exists() for f in ext_registry.INIT_FILES);
        if not has_init and not (pkg_copy / "__init__.py").exists() {
            (pkg_copy / "__init__.jac").write_text("");
        }

        if not _bake_serve_payloads(config, pkg_copy) {
            return None;
        }
        if not _bake_native_payloads(config, pkg_copy) {
            return None;
        }

        rc = _run_precompiler(str(stage), ["--seal"]);
        if rc != 0 {
            console.error("Seal failed.");
            return None;
        }

        parent.mkdir(parents=True, exist_ok=True);
        dest = parent / name;
        if dest.exists() {
            shutil.rmtree(dest);
        }
        shutil.move(str(pkg_copy), str(dest));
        return dest;
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
}

def _bundle_sealed(config: any, output: str) -> int {
    name = config.project.name;
    Path(output).mkdir(parents=True, exist_ok=True);
    console.print(f"\n  Sealing {name}...", style="muted");
    dest = _make_sealed_image(
        config, Path(output), f"{name}-sealed", out_dir=Path(output)
    );
    if dest is None {
        return 1;
    }
    console.print(
        f"  ✔ Sealed image at [cyan]{dest}[/cyan] (JIR-authoritative; _precompiled/MANIFEST.json; sources retained for tracebacks)",
        style="success"
    );
    console.print(
        "  Load in a host jac via jaclang.jac0core.sealed.register_image(<dir>/_precompiled).",
        style="muted"
    );
    return 0;
}

def _bundle_jab(config: any, output: str) -> int {
    import shutil;
    import tempfile;

    name = config.project.name;
    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    work = Path(tempfile.mkdtemp(prefix="jab-", dir=output));
    try {
        console.print(f"\n  Sealing {name}...", style="muted");
        img = _make_sealed_image(config, work, name, out_dir=Path(output));
        if img is None {
            return 1;
        }
        payload = _tar_gz_dir(img);
        out_jab = out_dir / f"{name}.jab";
        out_jab.write_bytes(payload);
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    console.print(
        f"  ✔ Built [cyan]{out_jab}[/cyan] ({out_jab.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Run it anywhere: jac run {out_jab.name}", style="muted");
    return 0;
}

def _bundle_binary(config: any, output: str) -> int {
    import sys;
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.jac0core.sealed { MANIFEST_NAME }
    import from jaclang.runtimelib.jab { jab_app_meta }

    name = config.project.name;
    jac_bin = os.path.realpath(sys.executable);

    if subprocess.run([jac_bin, "__hasruntime"], capture_output=True).returncode != 0 {
        console.error(
            "jac build --as binary needs a bundled single-file jac to carry the "
            "runtime; the current interpreter is not one (source / pip install).",
            hint="Run it with an installed single-file jac binary."
        );
        return 1;
    }

    Path(output).mkdir(parents=True, exist_ok=True);
    work = Path(tempfile.mkdtemp(prefix="jacbin-", dir=output));
    out_bin = Path(output) / name;
    try {
        console.print(f"\n  Sealing {name} for binary...", style="muted");
        img = _make_sealed_image(config, work, name, out_dir=Path(output));
        if img is None {
            return 1;
        }
        if not (img / "_precompiled" / MANIFEST_NAME).is_file() {
            console.error("Seal produced no manifest; aborting binary.");
            return 1;
        }

        if not (jab_app_meta(img).get("entry") or {}).get("path") {
            console.error(
                f"No runnable entry for '{name}'; a --as binary app needs an entry "
                "(main.jac at the package root, or [project] entry-point in jac.toml).",
                hint="Package-only projects have nothing to run as a binary."
            );
            return 1;
        }

        jab_path = work / f"{name}.jab";
        jab_path.write_bytes(_tar_gz_dir(img));

        console.print("  Appending app image onto the jac runtime...", style="muted");

        rc = subprocess.run(
            [jac_bin, "__appjab", str(jab_path), str(out_bin)]
        ).returncode;
        if rc != 0 or not out_bin.is_file() {
            console.error("Failed to append the app image onto the jac runtime.");
            return 1;
        }
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    console.print(
        f"  ✔ Built self-contained binary [cyan]{out_bin}[/cyan] "
        f"({out_bin.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Run it directly: {out_bin.resolve()}", style="muted");
    return 0;
}

def _tar_gz_dir(top: Path) -> bytes {
    import io;
    import gzip;
    import tarfile;
    import os;

    def normalize(ti: any) -> any {
        ti.mtime = 0;
        ti.uid = 0;
        ti.gid = 0;
        ti.uname = "";
        ti.gname = "";
        return ti;
    }

    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w") as tf {
        for (dirpath, dirnames, filenames) in os.walk(str(top)) {
            dirnames.sort();
            for fn in sorted(filenames) {
                full = Path(dirpath) / fn;
                tf.add(str(full), arcname=str(full.relative_to(top)), filter=normalize);
            }
        }
    }
    return gzip.compress(buf.getvalue(), 6, mtime=0);
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
    if target == "sealed" {
        return _bundle_sealed(config, output);
    }
    if target == "jab" {
        return _bundle_jab(config, output);
    }
    if target == "binary" {
        return _bundle_binary(config, output);
    }
    if target not in ("wheel", "npm", "all") {
        console.error(
            f"Unknown bundle target: '{target}'",
            hint="Use --target wheel, npm, sealed, binary, or all."
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
