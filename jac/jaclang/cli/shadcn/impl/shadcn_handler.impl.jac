import re;
import json as json_mod;
import from pathlib { Path }
import from jaclang.cli.console { console }

impl _read_shadcn_config(config: any) -> any {
    if config.project_root is None {
        return None;
    }
    if not hasattr(config, "_raw_data") or config._raw_data is None {
        return None;
    }
    return config._raw_data.get("jac-shadcn");
}

impl _registry_dir -> Path {
    base = Path(__file__).parent.parent / "registry";
    if base.exists() {
        return base;
    }

    import from importlib.resources { files }
    try {
        return Path(str(files("jaclang.cli.shadcn"))) / "registry";
    } except (TypeError, ModuleNotFoundError) {
        return base;
    }
}

impl load_registry -> dict[str, any] {
    registry_path = _registry_dir() / "registry.json";
    if registry_path.is_file() {
        with open(registry_path, "r") as f {
            return json_mod.load(f);
        }
    }
    return {"version": "1.0.0", "components": {}, "sharedDeps": {}};
}

impl parse_style_css(style_name: str) -> dict[str, str] {
    style_path = _registry_dir() / "styles" / ("style-" + style_name + ".css");
    if not style_path.is_file() {
        return {};
    }
    with open(style_path, "r") as f {
        content = f.read();
    }

    content = re.sub(r'/\*.*?\*/', "", content, flags=re.DOTALL);
    pattern = re.compile(r'\.(cn-[\w-]+)\s*\{\s*@apply\s+([^;}]+)[;}]');
    resolution_map: dict[str, str] = {};
    for `match in pattern.findall(content) {
        resolution_map[`match[0]] = `match[1].strip();
    }
    return resolution_map;
}

impl resolve_component(source: str, resolution_map: dict[str, str]) -> str {
    sorted_keys = sorted(list(resolution_map.keys()), key=len, reverse=True);
    result = source;
    for key in sorted_keys {
        result = result.replace(key, resolution_map[key]);
    }
    return result;
}

impl resolve_single_component(component_name: str, style: str) -> dict[str, any] {
    registry = load_registry();
    components = registry.get("components", {});

    comp_meta = components.get(component_name);
    if not comp_meta {
        return {"error": "Component not found: " + component_name};
    }

    filename = comp_meta["file"];
    filepath = _registry_dir() / "components" / "ui" / filename;
    if not filepath.is_file() {
        return {"error": "Component file not found: " + filename};
    }

    resolution_map = parse_style_css(style);
    with open(filepath, "r") as f {
        source = f.read();
    }
    resolved = resolve_component(source, resolution_map);

    return {
        "name": component_name,
        "file": filename,
        "content": resolved,
        "npmDeps": comp_meta.get("npmDeps", []),
        "peerComponents": comp_meta.get("peerComponents", [])
    };
}

impl _resolve_peer_deps(
    requested: list[str], registry_data: dict[str, any], existing: set[str]
) -> list[str] {
    components = registry_data.get("components", {});
    to_install: list[str] = [];
    visited: set[str] = set();

    queue: list[str] = list(requested);
    while queue {
        name = queue.pop(0);

        if name not in components and name.replace("_", "-") in components {
            name = name.replace("_", "-");
        }
        if name in visited or name in existing {
            continue;
        }
        visited.add(name);

        comp = components.get(name);
        if not comp {
            console.warning("Component not found in registry: " + name);
            continue;
        }

        to_install.append(name);

        for peer in comp.get("peerComponents", []) {
            if peer not in visited and peer not in existing {
                queue.append(peer);
            }
        }
    }

    return to_install;
}

impl _update_npm_deps(config: any, npm_deps: dict[str, str]) -> None {
    if not npm_deps {
        return;
    }
    toml_path = Path(str(config.project_root)) / "jac.toml";
    with open(toml_path, "r") as f {
        content = f.read();
    }

    for key in npm_deps {
        ver = npm_deps[key];

        toml_key = key if re.`match(r'^[A-Za-z0-9_-]+$', key) else '"' + key + '"';

        if re.search(
            r'(?m)^\s*' + str(toml_key).replace('.', r'\.') + r'\s*=', content
        ) {
            continue;
        }
        marker = "[dependencies.npm]";
        idx = content.find(marker);
        if idx >= 0 {
            insert_pos = idx + len(marker);
            line = toml_key + ' = "' + ver + '"';
            content = content[:insert_pos] + "\n" + line + content[insert_pos:];
        }
    }

    with open(toml_path, "w") as f {
        f.write(content);
    }
}

impl _has_jac(path: Path) -> bool {
    if not path.is_dir() {
        return False;
    }
    for f in path.iterdir() {
        if f.name.endswith(".jac") {
            return True;
        }
    }
    return False;
}

impl _defines_cn(path: Path) -> bool {
    try {
        return "def:pub cn(" in path.read_text(encoding="utf-8");
    } except Exception {
        return False;
    }
}

impl _inside(project_root: Path, candidate: Path) -> Path | None {
    resolved = candidate.resolve();
    root_dir = project_root.resolve();
    if resolved == root_dir or root_dir in resolved.parents {
        return resolved;
    }
    return None;
}

impl _discover(
    project_root: Path, pattern: str, accept: Callable[[Path], bool]
) -> Path | None {
    for cand in sorted(project_root.rglob(pattern)) {
        if set(cand.relative_to(project_root).parts) & SKIP_DIRS {
            continue;
        }
        if accept(cand) and _inside(project_root, cand) is not None {
            return cand;
        }
    }
    return None;
}

impl _resolve_one(
    project_root: Path,
    shadcn_config: any,
    key: str,
    pattern: str,
    accept: Callable[[Path], bool],
    fallback: Path
) -> Path | None {
    raw = str(shadcn_config.get(key, "")) if shadcn_config else "";
    if raw {
        pinned = _inside(project_root, project_root / raw);
        if pinned is None {
            console.error(
                f"[jac-shadcn] {key} = '{raw}' resolves outside the project",
                hint="Use a path inside the project root, e.g. shared/ui"
            );
        }
        return pinned;
    }
    if fallback.exists() {
        kept = _inside(project_root, fallback);
        if kept is None {
            console.error(
                f"Refusing to follow {fallback.name} outside the project: {fallback}",
                hint="A symlink leaving the project tree is not followed."
            );
        }
        return kept;
    }
    found = _discover(project_root, pattern, accept);
    return found if found is not None else fallback;
}

impl _module_of(project_root: Path, path: Path) -> str {
    rel = path.relative_to(project_root);
    name = rel.name;
    for suf in [".jac"] {
        if name.endswith(suf) {
            name = name[:-len(suf)];
            break;
        }
    }
    return ".".join(list(rel.parts[:-1]) + [name]);
}

impl resolve_shadcn_paths(
    project_root: Path, shadcn_config: any
) -> ShadcnPaths | None {
    ui = _resolve_one(
        project_root,
        shadcn_config,
        "components_dir",
        "ui",
        _has_jac,
        project_root / "components" / "ui"
    );
    utils = _resolve_one(
        project_root,
        shadcn_config,
        "utils_path",
        "utils*.jac",
        _defines_cn,
        project_root / "lib" / "utils.jac"
    );
    if ui is None or utils is None {
        return None;
    }
    return ShadcnPaths(
        ui_dir=ui, utils_file=utils, utils_module=_module_of(project_root, utils)
    );
}

impl _retarget_utils_import(
    content: str, ui_dir: Path, project_root: Path, utils_mod: str
) -> str {
    depth = len(ui_dir.relative_to(project_root).parts);
    return re.sub(
        r"from \.+lib\.utils\b", "from " + ("." * (depth + 1)) + utils_mod, content
    );
}

impl add_shadcn_components(config: any, component_names: list[str]) -> bool {
    shadcn_config = _read_shadcn_config(config);
    if not shadcn_config {
        console.error(
            "No [jac-shadcn] section in jac.toml",
            hint="Create project with: jac create --use jac-shadcn"
        );
        return False;
    }

    style = shadcn_config.get("style", "nova");
    project_root = Path(str(config.project_root)).resolve();

    console.print("\n Adding components (style: " + style + ")\n", style="bold cyan");

    registry_data = load_registry();
    if not registry_data or not registry_data.get("components") {
        console.error("Bundled component registry is empty or missing.");
        return False;
    }

    paths = resolve_shadcn_paths(project_root, shadcn_config);
    if paths is None {
        return False;
    }
    ui_dir = paths.ui_dir;
    utils_path = paths.utils_file;
    utils_mod = paths.utils_module;
    if ui_dir != project_root / "components" / "ui" {
        where = str(ui_dir.relative_to(project_root));
        console.print(f"  Using {where} (cn() from {utils_mod})", style="muted");
    }
    existing: set = set();
    if ui_dir.exists() {
        for f in ui_dir.iterdir() {
            if f.name.endswith(".jac") {
                existing.add(f.name.replace(".jac", "").replace("_", "-"));
            }
        }
    }

    to_install = _resolve_peer_deps(component_names, registry_data, existing);
    if not to_install {
        console.info("All requested components are already installed.");
        return True;
    }

    auto_added: list = [];
    for name in to_install {
        if name not in component_names {
            auto_added.append(name);
        }
    }
    if auto_added {
        console.print(
            "  Auto-adding peer dependencies: " + ", ".join(auto_added), style="muted"
        );
    }

    ui_dir.mkdir(parents=True, exist_ok=True);

    all_npm_deps: dict = {};
    shared_deps = registry_data.get("sharedDeps", {});
    all_npm_deps.update(shared_deps);
    dep_versions = registry_data.get("depVersions", {});

    added: list = [];
    for name in to_install {
        comp_data = resolve_single_component(name, style);

        if not comp_data or "error" in comp_data {
            err_msg = str(comp_data.get("error", "Unknown error"))
                if comp_data
                else "No response";
            console.error("  x " + name + ": " + err_msg);
            continue;
        }

        filename = str(comp_data.get("file", name + ".jac")).replace("-", "_");
        content = _retarget_utils_import(
            str(comp_data.get("content", "")), ui_dir, project_root, utils_mod
        );
        out_path = ui_dir / filename;
        with open(out_path, "w") as f {
            f.write(content);
        }

        for dep in comp_data.get("npmDeps", []) {
            if dep not in all_npm_deps {
                all_npm_deps[dep] = dep_versions.get(dep, "*");
            }
        }

        added.append(name);
        console.print("  + " + name, style="green");
    }

    if all_npm_deps {
        _update_npm_deps(config, all_npm_deps);
        console.print("\n  Updated jac.toml [dependencies.npm]", style="muted");
    }

    if not utils_path.exists() {
        utils_path.parent.mkdir(parents=True, exist_ok=True);
        with open(utils_path, "w") as f {
            f.write(
                'import from "clsx" { clsx }\nimport from "tailwind-merge" { twMerge }\n\ndef:pub cn(*inputs: any) -> str {\n    return twMerge(clsx(inputs));\n}\n'
            );
        }
        made = str(utils_path.relative_to(project_root));
        console.print(f"  + Created {made}", style="green");
    }

    if added {
        console.print("");
        console.print(
            "Added " + str(len(added)) + " component(s): " + ", ".join(added),
            style="bold green"
        );
    }

    return len(added) > 0;
}

impl remove_shadcn_components(config: any, component_names: list[str]) -> bool {
    project_root = Path(str(config.project_root)).resolve();
    paths = resolve_shadcn_paths(project_root, _read_shadcn_config(config));
    if paths is None {
        return False;
    }
    ui_dir = paths.ui_dir;
    if not ui_dir.exists() {
        console.error(
            "No shadcn ui directory found.",
            hint="Looked for components/ui and any */ui holding .jac files; set [jac-shadcn] components_dir in jac.toml to point at yours."
        );
        return False;
    }

    registry_data = load_registry();
    components_meta = registry_data.get("components", {});

    removed: list = [];
    for name in component_names {
        comp = components_meta.get(name);
        filename = str(
            comp["file"] if comp and "file" in comp else (name + ".jac")
        ).replace(
            "-", "_"
        );
        filepath = ui_dir / filename;
        if not filepath.exists() {
            legacy = ui_dir / filename.replace(".jac", ".jac");
            if legacy.exists() {
                filepath = legacy;
            }
        }
        if filepath.exists() {
            filepath.unlink();
            removed.append(name);
            console.print("  - Removed " + name, style="green");
        } else {
            console.warning("  Component not found: " + name);
        }
    }

    if removed {
        console.print(
            "Removed " + str(len(removed)) + " component(s): " + ", ".join(removed),
            style="bold green"
        );
    }

    return len(removed) > 0;
}
