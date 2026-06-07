"""Implementation of shadcn component handler."""

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

impl _registry_dir -> any {
    # shadcn_handler.impl.jac is in jac_super/shadcn/impl/, so .parent.parent = jac_super/shadcn/
    base = Path(__file__).parent.parent / "registry";
    if base.exists() {
        return base;
    }
    # Fallback: resolve via installed package location
    import from importlib.resources { files }
    try {
        return Path(str(files("jac_super.shadcn"))) / "registry";
    } except (TypeError, ModuleNotFoundError) {
        return base;
    }
}

impl load_registry -> dict {
    registry_path = _registry_dir() / "registry.json";
    if registry_path.is_file() {
        with open(registry_path, "r") as f {
            return json_mod.load(f);
        }
    }
    return {"version": "1.0.0", "components": {}, "sharedDeps": {}};
}

impl parse_style_css(style_name: str) -> dict {
    style_path = _registry_dir() / "styles" / ("style-" + style_name + ".css");
    if not style_path.is_file() {
        return {};
    }
    with open(style_path, "r") as f {
        content = f.read();
    }

    pattern = re.compile(r'\.(cn-[\w-]+)\s*\{\s*@apply\s+([^;]+);');
    resolution_map: dict = {};
    for match in pattern.findall(content) {
        resolution_map[match[0]] = match[1].strip();
    }
    return resolution_map;
}

impl resolve_component(source: str, resolution_map: dict) -> str {
    # Sort keys longest-first so cn-foo-bar is replaced before cn-foo.
    sorted_keys = sorted(list(resolution_map.keys()), key=len, reverse=True);
    result = source;
    for key in sorted_keys {
        result = result.replace(key, resolution_map[key]);
    }
    return result;
}

impl resolve_single_component(component_name: str, style: str) -> dict {
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

impl _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list {
    components = registry_data.get("components", {});
    to_install: list = [];
    visited: set = set();

    queue: list = list(requested);
    while queue {
        name = queue.pop(0);
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

impl _update_npm_deps(config: any, npm_deps: dict) -> None {
    if not npm_deps {
        return;
    }
    toml_path = Path(str(config.project_root)) / "jac.toml";
    with open(toml_path, "r") as f {
        content = f.read();
    }

    for key in npm_deps {
        ver = npm_deps[key];
        # Scoped npm names (@scope/pkg) are not valid TOML bare keys -- quote them.
        toml_key = key if re.match(r'^[A-Za-z0-9_-]+$', key) else '"' + key + '"';
        # Line-anchored check so e.g. `shadcn` is not falsely matched by `[jac-shadcn]`.
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

impl add_shadcn_components(config: any, component_names: list) -> bool {
    shadcn_config = _read_shadcn_config(config);
    if not shadcn_config {
        console.error(
            "No [jac-shadcn] section in jac.toml",
            hint="Create project with: jac create --use jac-shadcn"
        );
        return False;
    }

    style = shadcn_config.get("style", "nova");
    project_root = Path(str(config.project_root));

    console.print("\n Adding components (style: " + style + ")\n", style="bold cyan");

    registry_data = load_registry();
    if not registry_data or not registry_data.get("components") {
        console.error("Bundled component registry is empty or missing.");
        return False;
    }

    ui_dir = project_root / "components" / "ui";
    existing: set = set();
    if ui_dir.exists() {
        for f in ui_dir.iterdir() {
            if f.suffix == ".jac" and f.name.endswith(".cl.jac") {
                # Files are written with underscores; registry names are kebab-case.
                existing.add(f.name.replace(".cl.jac", "").replace("_", "-"));
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

        # Hyphenated filenames are unimportable via jac-client dot-paths; use underscores.
        filename = str(comp_data.get("file", name + ".cl.jac")).replace("-", "_");
        content = str(comp_data.get("content", ""));
        out_path = ui_dir / filename;
        with open(out_path, "w") as f {
            f.write(content);
        }

        for dep in comp_data.get("npmDeps", []) {
            if dep not in all_npm_deps {
                all_npm_deps[dep] = "*";
            }
        }

        added.append(name);
        console.print("  + " + name, style="green");
    }

    if all_npm_deps {
        _update_npm_deps(config, all_npm_deps);
        console.print("\n  Updated jac.toml [dependencies.npm]", style="muted");
    }

    utils_path = ui_dir.parent.parent / "lib" / "utils.cl.jac";
    if not utils_path.exists() {
        utils_path.parent.mkdir(parents=True, exist_ok=True);
        with open(utils_path, "w") as f {
            f.write(
                'cl import from "clsx" { clsx }\ncl import from "tailwind-merge" { twMerge }\n\ndef:pub cn(*inputs: any) -> str {\n    return twMerge(clsx(inputs));\n}\n'
            );
        }
        console.print("  + Created lib/utils.cl.jac", style="green");
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

impl remove_shadcn_components(config: any, component_names: list) -> bool {
    project_root = Path(str(config.project_root));
    ui_dir = project_root / "components" / "ui";

    if not ui_dir.exists() {
        console.error("No components/ui directory found.");
        return False;
    }

    # Resolve each name to its installed filename via the registry's `file`
    # field -- some names differ from their file (e.g. `input-otp` installs as
    # `otp-input.cl.jac`), so `name + ".cl.jac"` would miss them. Fall back to
    # that form for names not in the registry (or already a bare file basename).
    registry_data = load_registry();
    components_meta = registry_data.get("components", {});

    removed: list = [];
    for name in component_names {
        comp = components_meta.get(name);
        filename = str(
            comp["file"] if comp and "file" in comp else (name + ".cl.jac")
        ).replace(
            "-", "_"
        );
        filepath = ui_dir / filename;
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
