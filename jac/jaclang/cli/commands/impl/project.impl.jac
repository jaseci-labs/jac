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
import from jaclang.dist.seal {
    make_sealed_image as _make_sealed_image,
    run_precompiler as _run_precompiler,
    tar_gz_dir as _tar_gz_dir,
    vendor_jab_deps as _vendor_jab_deps,
    build_jab
}
import type from jaclang.project.template_registry { ProjectTemplate, TemplateRegistry }

impl create(
    name: str = '',
    force: bool = False,
    kind: str = "",
    app: str = "",
    path: str = "",
    use: str = "default",
    awesome: bool = False,
    `list: bool = False,
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
    prev_skip_npm = os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL");
    if `skip {
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }
    try {
        return _create_body(
            name,
            force,
            kind,
            app,
            path,
            use,
            awesome,
            `list,
            `skip or bool(os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL")),
            style,
            baseColor,
            theme,
            font,
            radius,
            menuAccent,
            menuColor
        );
    } finally {
        if `skip {
            if prev_skip_npm is None {
                os.environ.pop("JAC_CLIENT_SKIP_NPM_INSTALL", None);
            } else {
                os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = prev_skip_npm;
            }
        }
    }
}

def _create_body(
    name: str,
    force: bool,
    kind: str,
    app_name: str,
    app_path: str,
    use: str,
    awesome: bool,
    list_kinds: bool,
    skip_deps: bool,
    style: str | None,
    baseColor: str | None,
    theme: str | None,
    font: str | None,
    radius: str | None,
    menuAccent: str | None,
    menuColor: str | None
) -> int {
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
        TemplateRegistry,
        get_template_registry
    }
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import from jaclang.project.kinds { is_valid_kind, VALID_KINDS }
    registry: TemplateRegistry = get_template_registry();

    if list_kinds {
        kinds = registry.list_kinds();
        if kinds {
            console.print(
                "\nProject kinds (jac create --kind <kind>):\n", style="info"
            );
            for (kname, desc) in kinds {
                console.print(f"  {kname}: {desc}");
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
    if app_name {
        if awesome or explicit_use {
            console.error(
                "--app scaffolds a built-in kind inside the current project; drop --awesome/--use.",
                hint="jac create --app <name> --kind <kind>"
            );
            return 1;
        }
        return _create_app(registry, app_name, kind, app_path, force);
    }
    if kind and explicit_use {
        console.error(
            "Use either --kind or --use, not both.",
            hint="--kind <kind> scaffolds a built-in kind; --use <path|url> a custom template."
        );
        return 1;
    }
    if awesome and (kind or explicit_use) {
        console.error(
            "--awesome is a complete template; drop --kind/--use.",
            hint="jac create <name> --awesome"
        );
        return 1;
    }
    if awesome {
        tmpl = _resolve_awesome_template();
        if tmpl is None {
            console.error(
                "The awesome template is not available in this jac build.",
                hint="It ships inside the released binary's payload (awesome_template beside the jaclang package) or a source checkout's examples/jaclang_org."
            );
            return 1;
        }
        if "apps" not in tmpl.config {
            console.error(
                "The awesome template has no [apps] table; the flagship is a workspace.",
                hint="examples/jaclang_org/jac.toml declares [apps.*]; refresh the bundled awesome_template."
            );
            return 1;
        }
    } elif explicit_use {
        tmpl = _resolve_template(use, registry);
        if tmpl is None {
            console.error(f"Unknown template: {use}");
            console.print(
                "Use --list to see available kinds and named variants.", style="muted"
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
        tmpl = registry.get_by_kind(target_kind);
        if tmpl is None {
            console.error(
                f"No template registered for kind '{target_kind}'.",
                hint="This is unexpected for a core kind; please report it."
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

            if Path(project_root).resolve() == cwd.resolve() {
                console.error(f"Already in a Jac project: {toml_path}");
                console.print("Use --force to reinitialize.", style="muted");
                return 1;
            }
            console.warning(
                f"Creating a nested project inside {project_root}; the "
                "nearest jac.toml wins for files under this directory.",
                emoji=False
            );
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
    console.print(f"\nCreating project '{project_name}'\n", style="bold cyan");
    console.print("  Setting up project structure", style="muted");

    import copy;
    render_config = copy.deepcopy(tmpl.config);
    _stamp_kind(render_config, tmpl.kind);
    _stamp_jac_version(render_config);

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

    deps_installed = False;
    if not skip_deps {
        deps_installed = _bootstrap_project_deps(project_path);
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
    if not deps_installed {
        steps.append("jac install           Install dependencies");
    }
    if "apps" in render_config {
        steps.append(
            "jac run               Run the default app (jac run --show lists every app)"
        );
    } else {
        steps.append(f"jac run               {_run_blurb(tmpl.kind)}");
    }
    console.print_next_steps(steps);
    console.print();
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

def _create_app(
    registry: TemplateRegistry, app_name: str, kind: str, app_path: str, force: bool
) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.kinds { is_valid_kind, VALID_KINDS }
    import from jaclang.project.template_loader { scaffold_app }

    existing = find_project_root(Path.cwd());
    if existing is None {
        console.error(
            "jac create --app needs an existing project.",
            hint="Run inside a project (jac.toml), or scaffold one first: jac create <name>"
        );
        return 1;
    }
    (project_root, toml_path) = existing;
    if not kind {
        console.error(
            "--app requires --kind.", hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
        );
        return 1;
    }
    if not is_valid_kind(kind) {
        console.error(
            f"Unknown app kind '{kind}'.", hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
        );
        return 1;
    }
    if "/" in app_name or "\\" in app_name or app_name.endswith(".jac") {
        console.error(
            f"'{app_name}' is not a valid app name.",
            hint="App names carry no path separators and no .jac suffix."
        );
        return 1;
    }
    tmpl = registry.get_by_kind(kind);
    if tmpl is None {
        console.error(
            f"No template registered for kind '{kind}'.",
            hint="This is unexpected for a core kind; please report it."
        );
        return 1;
    }
    rel_path = app_path or app_name;
    app_dir = Path(project_root) / rel_path;
    if app_dir.exists() and any(app_dir.iterdir()) and not force {
        console.error(
            f"Directory '{rel_path}' already exists and is not empty. Use --force to scaffold into it."
        );
        return 1;
    }
    console.print(
        f"\nAdding app '{app_name}' ({kind}) to {toml_path}\n", style="bold cyan"
    );
    apps_before = _toml_apps(Path(toml_path));
    try {
        written = scaffold_app(str(project_root), app_name, kind, rel_path, tmpl);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    for rel in written {
        console.print(f"  ✔ {rel}", style="success");
    }
    console.print(f"  ✔ jac.toml [apps.{app_name}]", style="success");
    (apps_after, default_app) = _toml_apps_and_default(Path(toml_path));
    for migrated in apps_after {
        if migrated not in apps_before and migrated != app_name {
            console.print(
                f"  ✔ jac.toml [apps.{migrated}] (the project's entry, now a "
                f"file-rooted app; default-app = {default_app or migrated})",
                style="success"
            );
        }
    }
    console.success(f"App '{app_name}' added");
    console.print_next_steps([f"jac run {app_name}".ljust(22) + _run_blurb(kind)]);
    console.print();
    return 0;
}

def _toml_apps_and_default(toml_path: Path) -> tuple[set[str], str] {
    import from jaclang.project.tomlio { read_toml_with_encoding }
    try {
        doc = read_toml_with_encoding(str(toml_path));
    } except Exception {
        return (set(), "");
    }
    apps = doc.get("apps", {});
    project = doc.get("project", {});
    default_app = str(project.get("default-app", ""))
        if isinstance(project, dict)
        else "";
    return (set(apps.keys()) if isinstance(apps, dict) else set(), default_app);
}

def _toml_apps(toml_path: Path) -> set[str] {
    return _toml_apps_and_default(toml_path)[0];
}

def _stamp_kind(config: dict, kind: str) -> None {
    if not kind or kind == "workspace" or "apps" in config {
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

def _stamp_jac_version(config: dict) {
    proj = config.get("project");
    if not isinstance(proj, dict) {
        proj = {};
        config["project"] = proj;
    }
    if not proj.get("jac-version") {
        import from jaclang.cli.cli { jac_version }
        proj["jac-version"] = f"=={jac_version()}";
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
- `jac run --dev main.jac` -- serve a web-app or service in dev mode
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

def _resolve_awesome_template -> ProjectTemplate | None {
    import jaclang;
    import from jaclang.project.template_loader { load_template_from_directory }
    pkg = Path(jaclang.__file__).parent;
    candidates = [
        pkg.parent / "awesome_template",
        pkg.parent / "examples" / "jaclang_org"
    ];
    for cand in candidates {
        if not (cand / "jac.toml").exists() {
            continue;
        }
        tmpl = load_template_from_directory(cand);

        tmpl.config.pop("dev", None);
        if isinstance(tmpl.config.get("project"), dict) {
            tmpl.config["project"]["name"] = "{{name}}";
        }
        return tmpl;
    }
    return None;
}

def _resolve_template(use: str, registry: TemplateRegistry) -> ProjectTemplate | None {
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import tempfile;
    import urllib.request;
    import urllib.error;

    if use.startswith("http://") or use.startswith("https://") {
        console.print(f"Downloading template from {use}");
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

    named = registry.get(use);
    if named is None {
        console.error(f"Unknown template: {use}");
        console.error("Use --list to see available kinds and named variants.");
        console.error("You can also specify a path to a .jacpack file or a URL.");
        return None;
    }
    return named;
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
    no_save: bool = False,
    git: str = "",
    npm: bool | None = None,
    shadcn: bool = False,
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
    if shadcn or npm {
        channel = "--shadcn" if shadcn else "--npm";

        flag_checks: list = [(no_save, "--no-save"), (dry_run, "--dry-run")];
        if shadcn {
            flag_checks.append((install_global, "--global"));
        }
        ineffective: list[str] = [
            flag
            for (enabled, flag) in flag_checks
            if enabled
        ];
        if ineffective {
            console.warning(
                f"{', '.join(ineffective)} has no effect with {channel} "
                "(it applies only to Python venv installs)."
            );
        }
    }
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_add }
        return run_shadcn_add(packages);
    }
    if npm {
        import from jaclang.client.cli { run_npm_add }
        return run_npm_add(packages, dev, install_global);
    }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv {
        ensure_venv,
        get_venv_site_packages,
        make_git_spec
    }
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

    if packages or git {
        if editable {
            console.error(
                "Cannot mix package names or --git with -e/--editable in a single command. "
                "Run them separately: 'jac install <pkg>' then 'jac install -e <path>'."
            );
            return 1;
        }
        save = not (no_save or install_global or dry_run);
        if extras {
            console.warning(
                "--extras has no effect with package names; "
                "declare optional groups in jac.toml instead."
            );
        }
        if dev and not save {
            console.warning(
                "--dev has no effect with --no-save/--global/--dry-run "
                "(nothing is recorded in jac.toml)."
            );
        }
        if install_global {
            specs: list = list(packages);
            if git {
                specs.append(make_git_spec(git));
            }
            console.print(
                f"\nInstalling {len(specs)} package(s) into the global site",
                style="bold"
            );
            if not python.install_specs(None, specs, global_ctx) {
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
        if git {
            if len(packages) > 1 {
                console.error(
                    f"Pass at most one name with --git (used as the dependency "
                    f"alias); got {len(packages)}: {', '.join(packages)}.",
                    hint="Install additional packages separately: 'jac install <pkg>'."
                );
                return 1;
            }
            if packages {
                pkg_name = packages[0];
            } else {
                pkg_name = git.rstrip("/").split("/")[-1];
                if pkg_name.endswith(".git") {
                    pkg_name = pkg_name[:-4];
                }
            }
            console.print(f"\nAdding {pkg_name} from git", style="bold");
            console.print(f"  Repository: {git}", style="muted");
            with console.status(
                f"Installing {pkg_name}...", spinner="dots"
            ) as status {
                git_success = python.install_specs(config, [make_git_spec(git)], ctx);
            }
            if not git_success {
                console.error(f"Failed to install {pkg_name}");
                return 1;
            }
            if dry_run {
                console.success("Dry run complete (nothing installed).");
                return 0;
            }
            console.print(f"  ✔ {pkg_name}", style="success");
            if save {
                config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
                config.save();
                console.print(
                    f"\n  ✔ Updated jac.toml [dependencies.git]", style="muted"
                );
            }
            return 0;
        }
        if not save {
            console.print(
                f"\nInstalling {len(packages)} package(s) into {config.get_venv_dir()}",
                style="bold"
            );
            return 0 if python.install_specs(config, packages, ctx) else 1;
        }
        console.print(f"\nAdding {len(packages)} Python package(s)", style="bold");
        parsed = [python.parse_spec(pkg_spec) for pkg_spec in packages];
        with console.status(
            f"Installing {len(packages)} package(s)...", spinner="dots"
        ) as status {
            recorded = python.add_packages(config, parsed, dev, ctx);
        }
        if recorded is None {
            console.error("Failed to install package(s)");
            return 1;
        }
        for ((name, _), version_str) in zip(parsed, recorded) {
            console.print(f"  ✔ {name} ({version_str})", style="success");
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

    editable = [p for group in (editable or []) for p in group];
    if editable {
        import from jaclang.dist.publish.builder { WheelBuilder }

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
                f"\nEditable: {config.project.name} ({src_dir})", style="bold"
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
    console.print(f"\nInstalling dependencies for {config.project.name}", style="bold");
    console.print(f"  Virtual environment: {config.get_venv_dir()}", style="muted");
    console.print();
    try {
        dep_plan = resolve_plan(config, include_dev=dev, extras=extras, scale=scale);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    if extras {
        console.print(f"  Extras: {', '.join(extras)}", style="muted");
    }
    if dep_plan.is_empty() {
        console.info("No dependencies to install.");
        return 0;
    }

    install_success = True;
    python_deps = dep_plan.for_ecosystem("python");
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
        if provider.name == "npm" and npm is False {
            console.print("\n  Skipping npm dependencies (--no-npm)", style="muted");
            continue;
        }
        provider_deps = dep_plan.for_ecosystem(provider.name);
        if not provider_deps {
            continue;
        }
        console.print(f"\n  Installing {provider.name} dependencies", style="muted");
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

def _bootstrap_project_deps(project_path: Path) -> bool {
    import from jaclang.project.config { get_config, set_config }
    prev = os.getcwd();
    prev_cfg = get_config();
    try {
        os.chdir(str(project_path));

        set_config(get_config(start_path=project_path, force_discover=True));
        return install() == 0;
    } except Exception as e {
        console.warning(f"Could not install dependencies: {e}");
        console.print(
            "  Run 'jac install' in the project directory when ready.\n", style="muted"
        );
        return False;
    } finally {
        os.chdir(prev);
        set_config(prev_cfg);
    }
}

impl remove(
    packages: list = [], dev: bool = False, npm: bool = False, shadcn: bool = False
) -> int {
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_remove }
        return run_shadcn_remove(packages);
    }
    if npm {
        import from jaclang.client.cli { run_npm_remove }
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
        f"\nUpdating {len(specs_to_update)} package(s) for {config.project.name}",
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
        f"\nResolved dependency plan for {config.project.name}", style="bold"
    );
    for ecosystem in plan.ecosystems() {
        eco_deps = plan.for_ecosystem(ecosystem);
        console.print(f"\n  [{ecosystem}] ({len(eco_deps)})", style="info");
        width = max([len(d.name) for d in eco_deps]);
        for d in sorted(eco_deps, key=lambda (d) { (d.origin, d.name); }) {
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
            console.print('  dev = "jac run --dev main.jac"', style="muted");
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
    import from jaclang.project.template_registry {
        TemplateRegistry,
        get_template_registry
    }
    import from jaclang.project.template_loader {
        load_template_from_directory,
        load_template_from_json,
        bundle_template
    }
    if not action or action == "list" {
        registry: TemplateRegistry = get_template_registry();
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
                import from jaclang.project.tomlio { read_toml_with_encoding }
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
    import from jaclang.dist.publish.builder { WheelBuilder }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    builder = WheelBuilder(config=config, project_root=config.project_root);

    console.print("\n  Transpiling Jac → Python and building wheel", style="muted");
    try {
        whl_path = builder.build_to(out_dir);
    } except Exception as e {
        console.error(f"Wheel build failed: {e}");
        return 1;
    }
    if builder.skipped_codespace {
        console.print(
            f"  ⚠ skipped {len(builder.skipped_codespace)} client "
            "client codespace file(s) — not part of a Python wheel",
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

    console.print("  Building sdist", style="muted");
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

def _bundle_sealed(config: any, output: str, app: str = "") -> int {
    name = config.project.name;
    Path(output).mkdir(parents=True, exist_ok=True);
    console.print(f"\n  Sealing {name}", style="muted");
    dest = _make_sealed_image(
        config, Path(output), f"{name}-sealed", out_dir=Path(output), app=app
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

def _bundle_jab(config: any, output: str, fat: bool = False, app: str = "") -> int {
    name = config.project.name;
    out_jab = Path(output) / f"{name}.jab";
    console.print(f"\n  Sealing {name}", style="muted");
    try {
        build_jab(config, out_jab, app=app, fat=fat);
    } except RuntimeError as e {
        console.error(str(e));
        return 1;
    }
    console.print(
        f"  ✔ Built [cyan]{out_jab}[/cyan] ({out_jab.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Run it anywhere: jac run {out_jab.name}", style="muted");
    return 0;
}

def _bundle_binary(config: any, output: str, fat: bool = False, app: str = "") -> int {
    import sys;
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.jac0core.sealed { MANIFEST_NAME }
    import from jaclang.dist.jab { jab_app_meta }

    name = config.project.name;
    jac_bin = os.path.realpath(sys.executable);

    import from jaclang.dist.fused_binary { has_runtime, append_overlay }
    if not has_runtime(jac_bin) {
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
        console.print(f"\n  Sealing {name} for binary", style="muted");
        img = _make_sealed_image(config, work, name, out_dir=Path(output), app=app);
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

        if fat and not _vendor_jab_deps(config, img) {
            return 1;
        }

        jab_path = work / f"{name}.jab";
        jab_path.write_bytes(_tar_gz_dir(img));

        console.print("  Appending app image onto the jac runtime", style="muted");

        if not append_overlay(jac_bin, str(jab_path), str(out_bin))
            or not out_bin.is_file() {
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

def _bundle_npm(config: any, output: str) -> int {
    import from jaclang.dist.publish.npm_builder { NpmBuilder }
    import from jaclang.dist.publish.npm_sources { NpmBoundaryError }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    console.print("\n  Building npm tarball", style="muted");
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
    import from jaclang.dist.publish.runtime_npm { build_runtime_to, runtime_pkg_name }
    import importlib.metadata;

    version = importlib.metadata.version("jaclang");
    pkg_name = runtime_pkg_name(framework);
    out_dir = Path(output);
    console.print(f"\nBuilding {pkg_name} v{version}", style="bold");
    console.print("\n  Compiling runtime → npm tarball", style="muted");
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

impl bundle(
    output: str = "dist", target: str = "wheel", fat: bool = False, app: str = ""
) -> int {
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
        return _bundle_sealed(config, output, app=app);
    }
    if target == "jab" {
        return _bundle_jab(config, output, fat=fat, app=app);
    }
    if target == "binary" {
        return _bundle_binary(config, output, fat=fat, app=app);
    }
    if target not in ("wheel", "npm", "all") {
        console.error(
            f"Unknown bundle target: '{target}'",
            hint="Use --target wheel, npm, sealed, binary, or all."
        );
        return 1;
    }

    console.print(
        f"\nBundling {config.project.name} " f"v{config.project.version} ({target})",
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
