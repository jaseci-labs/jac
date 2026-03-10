"""Implementation of shadcn component handler."""

import os;
import json as json_mod;
import from pathlib { Path }
import from jaclang.cli.console { console }

impl _read_shadcn_config(config: Any) -> Any {
    if config.project_root is None {
        return None;
    }
    if not hasattr(config, "_raw_data") or config._raw_data is None {
        return None;
    }
    return config._raw_data.get("jac-shadcn");
}

impl _fetch_json(url: str) -> Any {
    import urllib.request;
    import urllib.error;

    try {
        req = urllib.request.Request(url);
        req.add_header("Accept", "application/json");
        with urllib.request.urlopen(req, timeout=30) as response {
            raw = response.read().decode("utf-8");
        }
        data = json_mod.loads(raw);
        if isinstance(data, dict)
        and "data" in data
        and isinstance(data.get("data"), dict)
        and "result" in data["data"] {
            return data["data"]["result"];
        }
        return data;
    } except urllib.error.URLError as e {
        console.error("Network error: " + str(e));
        return None;
    } except Exception as e {
        console.error("Error fetching " + url + ": " + str(e));
        return None;
    }
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

impl _update_npm_deps(config: Any, npm_deps: dict) -> None {
    if not npm_deps {
        return;
    }
    toml_path = Path(str(config.project_root)) / "jac.toml";
    with open(toml_path, "r") as f {
        content = f.read();
    }

    for key in npm_deps {
        ver = npm_deps[key];
        if key in content {
            continue;
        }
        marker = "[dependencies.npm]";
        idx = content.find(marker);
        if idx >= 0 {
            insert_pos = idx + len(marker);
            line = key + ' = "' + ver + '"';
            content = content[:insert_pos] + "\n" + line + content[insert_pos:];
        }
    }

    with open(toml_path, "w") as f {
        f.write(content);
    }
}

impl add_shadcn_components(config: Any, component_names: list) -> bool {
    shadcn_config = _read_shadcn_config(config);
    if not shadcn_config {
        console.error(
            "No [jac-shadcn] section in jac.toml",
            hint="Create project with: jac create --use jac-shadcn"
        );
        return False;
    }

    style = shadcn_config.get("style", "nova");
    registry_url = shadcn_config.get("registry", "https://jac-shadcn.jaseci.org");
    project_root = Path(str(config.project_root));

    console.print("\n Adding components (style: " + style + ")\n", style="bold cyan");

    registry_data = _fetch_json(registry_url + "/registry");
    if not registry_data {
        console.error("Could not fetch component registry from " + registry_url);
        return False;
    }

    ui_dir = project_root / "components" / "ui";
    existing: set = set();
    if ui_dir.exists() {
        for f in ui_dir.iterdir() {
            if f.suffix == ".jac" and f.name.endswith(".cl.jac") {
                existing.add(f.name.replace(".cl.jac", ""));
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
        comp_data = _fetch_json(registry_url + "/component/" + name + "?style=" + style);

        if not comp_data or "error" in comp_data {
            err_msg = str(comp_data.get("error", "Unknown error"))
                if comp_data
                else "No response";
            console.error("  x " + name + ": " + err_msg);
            continue;
        }

        filename = comp_data.get("file", name + ".cl.jac");
        content = comp_data.get("content", "");
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
                'cl import from "clsx" { clsx }\ncl import from "tailwind-merge" { twMerge }\n\ndef:pub cn(...inputs: Any) -> str {\n    return twMerge(clsx(inputs));\n}\n'
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

impl remove_shadcn_components(config: Any, component_names: list) -> bool {
    project_root = Path(str(config.project_root));
    ui_dir = project_root / "components" / "ui";

    if not ui_dir.exists() {
        console.error("No components/ui directory found.");
        return False;
    }

    removed: list = [];
    for name in component_names {
        filepath = ui_dir / (name + ".cl.jac");
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
