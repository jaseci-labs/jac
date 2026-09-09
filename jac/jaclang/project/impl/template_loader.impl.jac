import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.template_registry { ProjectTemplate, template_kind_for }
import from jaclang.project.tomlio { read_toml_with_encoding }
import json;
import importlib;
import base64;
import from jaclang.cli.console { console }

def _read_file_content(file_path: Path) -> str {
    try {
        return file_path.read_text(encoding="utf-8");
    } except UnicodeDecodeError {
        binary_content = file_path.read_bytes();
        encoded = base64.b64encode(binary_content).decode("ascii");
        return "base64:" + encoded;
    }
}

impl load_template_from_directory(
    template_dir: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate {
    template_dir = Path(template_dir);
    if not template_dir.is_dir() {
        raise ValueError(f"Template directory not found: {template_dir}");
    }

    jac_toml_path = template_dir / "jac.toml";
    if not jac_toml_path.exists() {
        raise ValueError(f"No jac.toml found in {template_dir}");
    }
    jac_config = read_toml_with_encoding(str(jac_toml_path));

    jacpackk_section = jac_config.get("jacpack", {});
    if not jacpackk_section {
        raise ValueError(f"jac.toml must have [jacpack] section to be packable");
    }
    name = jacpackk_section.get("name");
    if not name {
        raise ValueError("jac.toml [jacpack] must have name field");
    }
    description = jacpackk_section.get("description", "");
    if not description {
        raise ValueError(
            f"jac.toml [jacpack] for '{name}' must have description field"
        );
    }

    config: dict[str, any] = {};
    for (key, value) in jac_config.items() {
        if key != "jacpack" {
            config[key] = value;
        }
    }

    options = jacpackk_section.get("options", {});
    directories = options.get("directories", []);
    root_gitignore_entries = options.get("root_gitignore_entries", []);
    gitignore_path = template_dir / ".gitignore";
    if gitignore_path.exists() {
        try {
            gitignore_content = gitignore_path.read_text(encoding="utf-8").strip();
            if gitignore_content {
                for line in gitignore_content.split("\n") {
                    line = line.strip();
                    if line and not line.startswith("#") {
                        if line not in root_gitignore_entries {
                            root_gitignore_entries = root_gitignore_entries + [line];
                        }
                    }
                }
            }
        } except Exception {}
    }
    if ".jac/" not in root_gitignore_entries {
        root_gitignore_entries = root_gitignore_entries + [".jac/"];
    }

    hook = post_create_hook;
    if hook is None and "post_create_hook" in options {
        hook = resolve_post_create_hook(options["post_create_hook"]);
    }

    files: dict[str, str] = {};
    file_patterns = options.get("files", None);
    if file_patterns {
        for pattern in file_patterns {
            for file_path in template_dir.`glob(pattern) {
                if file_path.is_file() and file_path.name != "jac.toml" {
                    relative_path = str(file_path.relative_to(template_dir));
                    files[relative_path] = _read_file_content(file_path);
                }
            }
        }
    } else {
        for file_path in template_dir.rglob("*") {
            if file_path.is_file() {
                relative_path = str(file_path.relative_to(template_dir));

                if relative_path != "jac.toml"
                    and not relative_path.startswith(".")
                    and "/." not in relative_path {
                    files[relative_path] = _read_file_content(file_path);
                }
            }
        }
    }

    apps_table = config.get("apps");
    if isinstance(apps_table, dict) and apps_table {
        import from jaclang.project.apps { parse_apps }
        try {
            parse_apps(config.get("project", {}), apps_table);
        } except ValueError as exc {
            raise ValueError(f"Template '{name}' has an invalid [apps] table: {exc}");
        }
    }
    kind = template_kind_for(config);
    default_for_kind = options.get("default_for_kind", True);
    return ProjectTemplate(
        name=name,
        description=description,
        kind=kind,
        is_default_for_kind=default_for_kind,
        config=config,
        files=files,
        directories=directories,
        root_gitignore_entries=root_gitignore_entries,
        post_create=hook
    );
}

impl bundle_template(template_dir: Path, output_path: Path) -> None {
    template_dir = Path(template_dir);
    output_path = Path(output_path);
    if not template_dir.is_dir() {
        raise ValueError(f"Template directory not found: {template_dir}");
    }

    jac_toml_path = template_dir / "jac.toml";
    if not jac_toml_path.exists() {
        raise ValueError(f"No jac.toml found in {template_dir}");
    }
    jac_config = read_toml_with_encoding(str(jac_toml_path));
    jacpackk_section = jac_config.get("jacpack", {});
    if not jacpackk_section {
        raise ValueError(f"jac.toml must have [jacpack] section to be packable");
    }

    template = load_template_from_directory(template_dir, post_create_hook=None);

    template_data = template.to_dict();

    if "jaclang" in jacpackk_section {
        template_data["jaclang"] = jacpackk_section["jaclang"];
    }
    if "plugins" in jacpackk_section {
        template_data["plugins"] = jacpackk_section["plugins"];
    }

    options = jacpackk_section.get("options", {});
    if "post_create_hook" in options {
        template_data["post_create_hook"] = options["post_create_hook"];
    }

    with open(output_path, "w", encoding="utf-8") as f {
        json.dump(template_data, f, indent=2);
    }
    console.print(f"Bundled template '{template.name}' to {output_path}");
}

impl load_template_from_json(
    json_path: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate {
    json_path = Path(json_path);
    if not json_path.exists() {
        raise ValueError(f"Template JSON not found: {json_path}");
    }
    with open(json_path, "r", encoding="utf-8") as f {
        data = json.load(f);
    }

    if "data" in data
        and isinstance(data.get("data"), dict)
        and "result" in data["data"] {
        unwrapped = data["data"]["result"];
        if isinstance(unwrapped, dict)
            and "name" in unwrapped
            and "files" in unwrapped {
            data = unwrapped;
        }
    }

    hook = post_create_hook;
    if hook is None and "post_create_hook" in data {
        hook = resolve_post_create_hook(data["post_create_hook"]);
    }
    kind = template_kind_for(data.get("config", {}), str(data.get("kind") or ""));
    return ProjectTemplate(
        name=data["name"],
        description=data["description"],
        kind=kind,
        is_default_for_kind=data.get("is_default_for_kind", True),
        config=data.get("config", {}),
        files=data.get("files", {}),
        directories=data.get("directories", []),
        root_gitignore_entries=data.get("root_gitignore_entries", []),
        post_create=hook
    );
}

impl resolve_post_create_hook(hook_path: str) -> Callable | None {
    if not hook_path {
        return None;
    }
    try {
        if ":" in hook_path {
            parts = hook_path.split(":");
            module_path = parts[0];
            func_name = parts[1];
        } else {
            parts = hook_path.rsplit(".", 1);
            if len(parts) != 2 {
                raise ValueError(f"Invalid hook path format: {hook_path}");
            }
            module_path = parts[0];
            func_name = parts[1];
        }

        module = importlib.import_module(module_path);
        hook = getattr(module, func_name);

        if not callable(hook) {
            raise ValueError(f"Hook '{hook_path}' is not callable");
        }

        return hook;
    } except ImportError as e {
        console.print(f"Warning: Could not import hook module '{hook_path}': {e}");
        return None;
    } except AttributeError as e {
        console.print(f"Warning: Hook function not found '{hook_path}': {e}");
        return None;
    }
}

impl scaffold_app(
    project_root: str, name: str, kind: str, path: str, template: ProjectTemplate
) -> list[str] {
    import os;
    import tomllib;
    import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
    import from jaclang.project.apps { APP_TABLE_KEYS, parse_apps, validate_app_name }
    import from jaclang.project.config { _toml_append_section }
    import from jaclang.project.kinds { KIND_SPECS, kind_entry }
    validate_app_name(name);
    if kind not in KIND_SPECS {
        raise ValueError(
            f"Unknown app kind '{kind}'; expected one of {', '.join(KIND_SPECS.keys())}"
        );
    }
    root_path = Path(project_root).resolve();
    toml_path = root_path / "jac.toml";
    if not toml_path.exists() {
        raise ValueError(f"No jac.toml in {root_path}; create a project first");
    }
    app_path = (path or name).strip().replace("\\", "/").strip("/");
    if not app_path or os.path.isabs(app_path) or app_path.startswith("..") {
        raise ValueError(f"App path '{path}' must be a directory inside the project");
    }
    text = read_file_with_encoding(str(toml_path));
    doc = tomllib.loads(text);
    apps_table = doc.get("apps", {});
    if not isinstance(apps_table, dict) {
        raise ValueError(f"[apps] in {toml_path} is not a table");
    }
    if name in apps_table {
        raise ValueError(f"App '{name}' already exists in {toml_path}");
    }
    for (other, table) in apps_table.items() {
        other_path = (
            str(table.get("path", "")).strip().strip("/")
                if isinstance(table, dict)
                else ""
        );
        if other_path and os.path.normpath(other_path) == os.path.normpath(app_path) {
            raise ValueError(
                f"Path '{app_path}' is already the root_path of app '{other}'"
            );
        }
    }
    lines: list[str] = text.split("\n");
    if not apps_table {
        base = JacConfig.load(toml_path);
        if base.resolve_app("").name == name {
            raise ValueError(
                f"App '{name}' collides with the project's own app name; "
                "pick another name"
            );
        }
        migrate_implicit_app(lines, base);
    }
    table: dict[str, any] = {"kind": kind, "path": app_path};
    tmpl_app = template_app_table(template);
    tmpl_entry = str(
        tmpl_app.get("entry-point", tmpl_app.get("entry_point", "")) or ""
    );
    if tmpl_entry and tmpl_entry != kind_entry(kind) {
        table["entry-point"] = tmpl_entry;
    }
    for (key, value) in tmpl_app.items() {
        attr = str(key).replace("-", "_");
        if attr in ("kind", "path", "entry_point") or attr not in APP_TABLE_KEYS {
            continue;
        }
        if isinstance(value, dict) or value is None or value == "" {
            continue;
        }
        table[str(key)] = value;
    }
    _toml_append_section(lines, ("apps", name), table);
    tmpl_deps = template.config.get("dependencies", {});
    tmpl_npm = tmpl_deps.get("npm") if isinstance(tmpl_deps, dict) else None;
    if isinstance(tmpl_npm, dict) and tmpl_npm {
        _append_overlay_tables(lines, ("apps", name, "dependencies", "npm"), tmpl_npm);
    }
    new_text = "\n".join(lines);
    new_doc = tomllib.loads(new_text);
    parse_apps(new_doc.get("project", {}), new_doc.get("apps", {}));
    toml_path.write_text(new_text, encoding="utf-8");

    created: list[str] = [];
    app_dir = root_path / app_path;
    app_dir.mkdir(parents=True, exist_ok=True);
    for (rel, content) in template.files.items() {
        full = app_dir / rel;
        if full.exists() {
            continue;
        }
        full.parent.mkdir(parents=True, exist_ok=True);
        if content.startswith("base64:") {
            full.write_bytes(base64.b64decode(content[7:]));
        } else {
            full.write_text(content.replace("{{name}}", name), encoding="utf-8");
        }
        created.append(str(full));
    }
    return created;
}

impl template_app_table(template: ProjectTemplate) -> dict[str, any] {
    apps = template.config.get("apps");
    if isinstance(apps, dict) and len(apps) == 1 {
        sole = next(iter(apps.values()));
        if isinstance(sole, dict) {
            return {
                k: v
                for (k, v) in sole.items()
                if not isinstance(v, dict)
            };
        }
        return {};
    }
    project = template.config.get("project", {});
    if not isinstance(project, dict) {
        return {};
    }
    entry_point = str(project.get("entry-point", "") or "");
    return {"entry-point": entry_point} if entry_point else {};
}

impl migrate_implicit_app(lines: list[str], base: JacConfig) -> str {
    import from jaclang.project.config {
        _toml_append_section,
        _toml_delete_key,
        _toml_insert_key,
        toml_value
    }
    import from jaclang.project.kinds { kind_entry }
    base_app = base.resolve_app("");
    base_kind = base.resolved_kind(base_app);
    for key in ("kind", "entry-point", "entry_point") {
        _toml_delete_key(lines, ("project", ), key);
    }
    default_line = toml_value(base_app.name);
    if not _toml_insert_key(lines, ("project", ), "default-app", default_line) {
        lines[0:0] = ["[project]", f"default-app = {default_line}", ""];
    }
    _toml_append_section(
        lines,
        ("apps", base_app.name),
        {
            "kind": base_kind,
            "entry-point": base_app.entry_point or kind_entry(base_kind)
        }
    );
    return base_app.name;
}

impl _append_overlay_tables(
    lines: list[str], parts: tuple[str, ...], table: dict[str, any]
) -> None {
    import from jaclang.project.config { _toml_append_section }
    flat: dict[str, any] = {};
    nested: list[tuple[str, dict[str, any]]] = [];
    for (k, v) in table.items() {
        if isinstance(v, dict) {
            nested.append((str(k), v));
        } else {
            flat[str(k)] = v;
        }
    }
    if flat {
        _toml_append_section(lines, parts, flat);
    }
    for (sub, sub_table) in nested {
        _append_overlay_tables(lines, parts + (sub, ), sub_table);
    }
}
