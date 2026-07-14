import from typing { Callable }
import from pathlib { Path }
import from jaclang.project.template_registry { ProjectTemplate }
import from jaclang.jac0core.helpers { read_toml_with_encoding }
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
        } except Exception { }
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
            for file_path in template_dir.glob(pattern) {
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

    kind = config.get("project", {}).get("kind", "") or "cli";
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
    kind = data.get("kind")
    or data.get("config", {}).get("project", {}).get("kind", "")
    or "cli";
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
