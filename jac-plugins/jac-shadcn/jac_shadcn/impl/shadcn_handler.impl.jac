"""Implementation of shadcn component handler."""

import os;
import json as json_mod;
import tomlkit;
import difflib;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jac_shadcn.lockfile {
    record_install,
    record_remove,
    compute_orphan_deps,
    load_lockfile,
}

glob DEFAULT_COMPONENT_VERSION: str = "1.0.0";

"""Components installed by default on `jac shadcn init` (without --all or
--bare). Covers form + nav + layout + status + loading basics. Keep the
list short so `jac shadcn init` finishes fast on a fresh project; users
add the rest incrementally via `jac shadcn add`."""
glob ESSENTIAL_COMPONENTS: list = [
         "button",
         "card",
         "input",
         "label",
         "dialog",
         "dropdown-menu",
         "separator",
         "badge",
         "avatar",
         "skeleton",

     ];

glob _MANAGED_BEGIN: str = "/* === jac-shadcn:managed BEGIN === */";
glob _MANAGED_END: str = "/* === jac-shadcn:managed END === */";
glob _USER_BEGIN: str = "/* === jac-shadcn:user BEGIN === */";
glob _USER_END: str = "/* === jac-shadcn:user END === */";
glob _USER_PLACEHOLDER: str = "/* Anything between these markers survives `jac shadcn upgrade`. */";


"""Extract the content between USER BEGIN/END markers in an existing
global.css. Returns "" if the file is absent or has no markers
(legacy format)."""
def _extract_user_css_block(css_path: Path) -> str {
    if not css_path.exists() {
        return "";
    }
    content = css_path.read_text();
    begin = content.find(_USER_BEGIN);
    end = content.find(_USER_END);
    if begin < 0 or end < 0 or end < begin {
        return "";
    }
    inner = content[begin + len(_USER_BEGIN):end];
    return inner.strip();
}


"""Rewrite the `themeClasses = "..."` line in the project's main.jac so the
app-shell body classes match the chosen style + baseColor. The template
ships markers (JAC-SHADCN-THEME-CLASSES-BEGIN/END) around the line so we
can patch in place without disturbing the rest of main.jac.

No-op when main.jac is absent or the markers aren't present (user
removed or rewrote main.jac -- we don't want to clobber their work)."""
def _patch_main_jac_theme_classes(
    project_root: Path, style: str, base_color: str
) -> None {
    import re;
    main_path = project_root / "main.jac";
    if not main_path.exists() {
        return;
    }
    content = main_path.read_text();
    if "JAC-SHADCN-THEME-CLASSES-BEGIN" not in content {
        return;
    }
    new_line = (
        '        themeClasses = "style-' + style + ' base-color-' + base_color + ' dark";'
    );
    pattern = r'(# JAC-SHADCN-THEME-CLASSES-BEGIN\n)        themeClasses = "[^"]*";';
    replacement = r'\1' + new_line;
    updated = re.sub(pattern, replacement, content);
    if updated != content {
        main_path.write_text(updated);
    }
}


"""Compose a managed/user-split global.css. The managed block is regenerated
on every init/upgrade; the user block is preserved verbatim across runs."""
def _compose_global_css(managed_css: str, user_block: str) -> str {
    user_body = user_block if user_block else _USER_PLACEHOLDER;
    return (
        _MANAGED_BEGIN + "\n" + managed_css.rstrip() + "\n" + _MANAGED_END + "\n\n" + _USER_BEGIN + "\n" + user_body + "\n" + _USER_END + "\n"
    );
}

impl _read_shadcn_config(config: any) -> any {
    if config.project_root is None {
        return None;
    }
    if not hasattr(config, "_raw_data") or config._raw_data is None {
        return None;
    }
    return config._raw_data.get("jac-shadcn");
}

impl _fetch_json(url: str, silent: bool = False) -> any {
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
        if not silent {
            console.error(
                "Network error fetching " + url + ": " + str(e),
                hint=(
                    "Check internet connectivity, or override the registry via "
                    "[jac-shadcn].registry in jac.toml."
                )
            );
        }
        return None;
    } except Exception as e {
        if not silent {
            console.error(
                "Error fetching " + url + ": " + str(e),
                hint="Registry may be returning malformed JSON; try again later."
            );
        }
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
            suggestions = _suggest_close_matches(name, list(components.keys()));
            if suggestions {
                console.warning(
                    "Component not found in registry: " + name + " (did you mean: " + ", ".join(
                        suggestions
                    ) + "?)"
                );
            } else {
                console.warning("Component not found in registry: " + name);
            }
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

impl _validate_component_filename(name: str, filename: any) -> str | None {
    if filename is None or not isinstance(filename, str) or not filename {
        console.error("  x " + name + ": registry returned empty filename");
        return None;
    }
    bad_chars = ["..", "/", "\\", "\x00"];
    for token in bad_chars {
        if token in filename {
            console.error(
                "  x " + name + ": registry returned suspicious filename '" + filename + "' (contains '" + token + "') -- refusing to write"
            );
            return None;
        }
    }
    if Path(filename).is_absolute() {
        console.error(
            "  x " + name + ": registry returned absolute path '" + filename + "' -- refusing to write"
        );
        return None;
    }
    if not filename.endswith(".cl.jac") {
        console.error(
            "  x " + name + ": registry returned filename '" + filename + "' (expected '.cl.jac' suffix) -- refusing to write"
        );
        return None;
    }
    return filename;
}

"""Load jac.toml with tomlkit (preserves comments + formatting on round-trip)."""
def _load_toml(toml_path: Path) -> any {
    with open(toml_path, "r") as f {
        return tomlkit.parse(f.read());
    }
}

"""Write jac.toml from a tomlkit document."""
def _save_toml(toml_path: Path, doc: any) -> None {
    with open(toml_path, "w") as f {
        f.write(tomlkit.dumps(doc));
    }
}

"""Ensure a nested table exists at `path` (e.g. ['dependencies', 'npm'])
and return it. Creates intermediate tables as needed."""
def _ensure_table(doc: any, path: list) -> any {
    cur = doc;
    for key in path {
        if key not in cur {
            cur[key] = tomlkit.table();
        }
        cur = cur[key];
    }
    return cur;
}

impl _patch_toml_section(toml_path: Path, section_path: list, deps: dict) -> None {
    if not deps {
        return;
    }
    doc = _load_toml(toml_path);
    section = _ensure_table(doc, section_path);
    for key in deps {
        if key in section {
            continue;
        }
        section[key] = deps[key];
    }
    _save_toml(toml_path, doc);
}

impl _update_npm_deps(config: any, npm_deps: dict) -> None {
    if not npm_deps {
        return;
    }
    toml_path = Path(str(config.project_root)) / "jac.toml";
    _patch_toml_section(toml_path, ["dependencies", "npm"], npm_deps);
}

impl _remove_npm_deps(toml_path: Path, keys: list) -> list {
    if not keys {
        return [];
    }
    if not toml_path.exists() {
        return [];
    }
    doc = _load_toml(toml_path);
    deps_table = doc.get("dependencies");
    if deps_table is None {
        return [];
    }
    npm_table = deps_table.get("npm");
    if npm_table is None {
        return [];
    }
    pruned: list = [];
    for key in keys {
        if key in npm_table {
            del npm_table[key];
            pruned.append(key);
        }
    }
    if pruned {
        _save_toml(toml_path, doc);
    }
    return pruned;
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
    registry_url = shadcn_config.get("registry", "https://jac-shadcn.jaseci.org");
    project_root = Path(str(config.project_root));

    # Parse `name@version` from each requested package; default to latest.
    parsed_requests: dict = {};
    bare_names: list = [];
    for raw in component_names {
        if "@" in raw {
            parts = raw.split("@", 1);
            parsed_requests[parts[0]] = parts[1];
            bare_names.append(parts[0]);
        } else {
            bare_names.append(raw);
        }
    }

    console.print("\n Adding components (style: " + style + ")\n", style="bold cyan");

    registry_data = _fetch_json(registry_url + "/registry");
    if not registry_data {
        console.error(
            "Could not fetch component registry from " + registry_url,
            hint=(
                "Verify [jac-shadcn].registry in jac.toml points at a reachable "
                "jac-shadcn registry server."
            )
        );
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

    to_install = _resolve_peer_deps(bare_names, registry_data, existing);
    if not to_install {
        console.info("All requested components are already installed.");
        return True;
    }

    auto_added: list = [];
    for name in to_install {
        if name not in bare_names {
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
        fetch_url = registry_url + "/component/" + name + "?style=" + style;
        if name in parsed_requests {
            fetch_url = fetch_url + "&version=" + parsed_requests[name];
        }
        comp_data = _fetch_json(fetch_url);

        if not comp_data or "error" in comp_data {
            err_msg = str(comp_data.get("error", "Unknown error"))
                if comp_data
                else "No response";
            console.error("  x " + name + ": " + err_msg);
            continue;
        }

        raw_filename = comp_data.get("file", name + ".cl.jac");
        filename = _validate_component_filename(name, raw_filename);
        if filename is None {
            continue;
        }
        content = comp_data.get("content", "");
        out_path = ui_dir / filename;
        with open(out_path, "w") as f {
            f.write(content);
        }

        comp_npm = list(comp_data.get("npmDeps", []));
        for dep in comp_npm {
            if dep not in all_npm_deps {
                all_npm_deps[dep] = "*";
            }
        }

        comp_version = str(comp_data.get("version", DEFAULT_COMPONENT_VERSION));
        record_install(project_root, name, comp_version, comp_npm);

        added.append(name);
        console.print("  + " + name + "@" + comp_version, style="green");
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

impl init_shadcn_theme(
    config: any,
    style: str = "nova",
    base_color: str = "neutral",
    theme: str = "neutral",
    font: str = "figtree",
    radius: str = "default",
    menu_accent: str = "subtle",
    install_set: str = "essential"
) -> bool {
    import from urllib.parse { urlencode }

    project_root = Path(str(config.project_root));

    # Registry URL: prefer existing [jac-shadcn].registry from jac.toml so
    # self-hosted mirrors are respected; fall back to the public default.
    existing = _read_shadcn_config(config);
    registry_url = "https://jac-shadcn.jaseci.org";
    if existing and existing.get("registry") {
        registry_url = str(existing["registry"]);
    }

    console.print("\n Initializing jac-shadcn theme\n", style="bold cyan");
    console.print(
        "  style=" + style + " baseColor=" + base_color + " theme=" + theme + " font=" + font + " radius=" + radius + " menuAccent=" + menu_accent,
        style="muted"
    );

    # Compose the /theme URL internally so users never have to type one.
    qs = urlencode(
        {
            "style": style,
            "baseColor": base_color,
            "theme": theme,
            "font": font,
            "radius": radius,
            "menuAccent": menu_accent
        }
    );
    fetch_url = registry_url + "/theme?" + qs;

    theme_data = _fetch_json(fetch_url);
    if not theme_data {
        console.error(
            "Could not fetch theme from " + fetch_url,
            hint=(
                "Verify [jac-shadcn].registry in jac.toml is reachable. "
                "Override with: jac shadcn init ... (and check the URL prints above)."
            )
        );
        return False;
    }

    # Write global.css. Preserves anything between the user markers across
    # re-runs; legacy files (no markers) are noted so the user can rescue
    # their customizations from VCS before re-running.
    global_css = theme_data.get("global_css", "");
    if global_css {
        css_path = project_root / "global.css";
        action_word = "Created";
        if css_path.exists() {
            user_block = _extract_user_css_block(css_path);
            if user_block {
                action_word = "Updated (user-section preserved)";
            } else {
                # File exists but no markers -- legacy format. Warn loudly
                # so the user can rescue their customizations from VCS.
                content = css_path.read_text();
                if _MANAGED_BEGIN not in content {
                    console.warning(
                        "  global.css has no jac-shadcn markers -- treating as "
                        "legacy. Anything you added is being replaced. To carry "
                        "customizations forward, paste them between "
                        "/* === jac-shadcn:user BEGIN === */ and "
                        "/* === jac-shadcn:user END === */ after this run."
                    );
                }
                action_word = "Replaced";
            }
        } else {
            user_block = "";
        }
        composed = _compose_global_css(global_css, user_block);
        with open(css_path, "w") as f {
            f.write(composed);
        }
        console.print("  + " + action_word + " global.css", style="green");
    }

    # Create lib/utils.cl.jac
    utils_path = project_root / "lib" / "utils.cl.jac";
    if not utils_path.exists() {
        utils_path.parent.mkdir(parents=True, exist_ok=True);
        with open(utils_path, "w") as f {
            f.write(
                'cl import from "clsx" { clsx }\ncl import from "tailwind-merge" { twMerge }\n\ndef:pub cn(...inputs: Any) -> str {\n    return twMerge(clsx(inputs));\n}\n'
            );
        }
        console.print("  + Created lib/utils.cl.jac", style="green");
    }

    # Create components/ui/ directory
    ui_dir = project_root / "components" / "ui";
    ui_dir.mkdir(parents=True, exist_ok=True);

    # Sync [jac-shadcn] section. Always writes the resolved values -- if the
    # section was scaffolded by the template, we overwrite with the user's
    # explicit choices. The `registry` key is preserved when present so a
    # user-pointed mirror is not clobbered.
    toml_path = project_root / "jac.toml";
    doc = _load_toml(toml_path);
    if "jac-shadcn" not in doc {
        doc["jac-shadcn"] = tomlkit.table();
    }
    section = doc["jac-shadcn"];
    section["style"] = style;
    section["baseColor"] = base_color;
    section["theme"] = theme;
    section["font"] = font;
    section["radius"] = radius;
    section["menuAccent"] = menu_accent;
    # Intentionally NOT writing `registry`: the public default lives in code
    # (this function above) so users get free upgrades when the URL changes.
    # If a user explicitly sets `[jac-shadcn].registry` for a self-hosted
    # mirror, we leave their value alone (we never overwrite it here).
    _save_toml(toml_path, doc);
    console.print("  + Synced [jac-shadcn] in jac.toml", style="green");

    # Keep the app shell's body classes in sync with the chosen theme
    # so the .style-* / .base-color-* CSS scopes match.
    _patch_main_jac_theme_classes(project_root, style, base_color);

    # Update npm deps using the section patcher
    npm_deps = theme_data.get("npm_deps", {});
    if npm_deps {
        _patch_toml_section(toml_path, ["dependencies", "npm"], npm_deps);
        console.print("  + Updated [dependencies.npm] in jac.toml", style="green");
    }

    # Update npm dev deps
    npm_dev_deps = theme_data.get("npm_dev_deps", {});
    if npm_dev_deps {
        _patch_toml_section(toml_path, ["dependencies", "npm", "dev"], npm_dev_deps);
        console.print("  + Updated [dependencies.npm.dev] in jac.toml", style="green");
    }

    # Add Vite/Tailwind plugin config if missing
    doc = _load_toml(toml_path);
    vite_config = theme_data.get("vite_config", {});
    needs_vite = vite_config
    and (
        "plugins" not in doc
        or doc.get("plugins", {}).get("client", {}).get("vite") is None
    );
    if needs_vite {
        vite_table = _ensure_table(doc, ["plugins", "client", "vite"]);
        vite_table["plugins"] = ["tailwindcss()"];
        vite_table["lib_imports"] = ["import tailwindcss from '@tailwindcss/vite'"];
        _save_toml(toml_path, doc);
        console.print(
            "  + Added [plugins.client.vite] Tailwind config to jac.toml", style="green"
        );
    }

    # Decide which components to install based on install_set:
    #   "bare"      -> none (theme/css only)
    #   "essential" -> the curated 10-component starter set (ESSENTIAL_COMPONENTS)
    #   "all"       -> every component the registry returns in default_components
    targets: list = [];
    set_label = install_set;
    if install_set == "bare" {
        targets = [];
        set_label = "bare (no components)";
    } elif install_set == "all" {
        targets = list(theme_data.get("default_components", []));
        set_label = "all";
    } else {
        targets = list(ESSENTIAL_COMPONENTS);
        set_label = "essentials";
    }

    if targets {
        console.print(
            "\n Installing " + set_label + " (" + str(len(targets)) + " component(s), style: " + style + ")\n",
            style="bold cyan"
        );

        comp_added: list = [];
        comp_npm_deps: dict = {};
        for comp_name in targets {
            comp_data = _fetch_json(
                registry_url + "/component/" + comp_name + "?style=" + style
            );
            if not comp_data or "error" in comp_data {
                err_msg = str(comp_data.get("error", "Unknown error"))
                    if comp_data
                    else "No response";
                console.error("  x " + comp_name + ": " + err_msg);
                continue;
            }

            raw_filename = comp_data.get("file", comp_name + ".cl.jac");
            filename = _validate_component_filename(comp_name, raw_filename);
            if filename is None {
                continue;
            }
            content = comp_data.get("content", "");
            out_path = ui_dir / filename;
            with open(out_path, "w") as f {
                f.write(content);
            }

            this_npm = list(comp_data.get("npmDeps", []));
            for dep in this_npm {
                if dep not in comp_npm_deps {
                    comp_npm_deps[dep] = "*";
                }
            }

            comp_version = str(comp_data.get("version", DEFAULT_COMPONENT_VERSION));
            record_install(project_root, comp_name, comp_version, this_npm);

            comp_added.append(comp_name);
            console.print("  + " + comp_name + "@" + comp_version, style="green");
        }

        # Update npm deps for component-specific dependencies
        if comp_npm_deps {
            _patch_toml_section(toml_path, ["dependencies", "npm"], comp_npm_deps);
        }

        if comp_added {
            console.print(
                "\nInstalled " + str(len(comp_added)) + " component(s)",
                style="bold green"
            );
        }
    }

    console.print(
        "\nTheme initialized! You can add more components with 'jac add --shadcn button card'.",
        style="bold green"
    );
    return True;
}

impl remove_shadcn_components(
    config: any, component_names: list, keep_deps: bool = False
) -> bool {
    project_root = Path(str(config.project_root));
    ui_dir = project_root / "components" / "ui";

    if not ui_dir.exists() {
        console.error(
            "No components/ui directory found.",
            hint="Run 'jac shadcn add <name>' first to install something."
        );
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

    pruned: list = [];
    if removed {
        if not keep_deps {
            orphans = compute_orphan_deps(project_root, removed);
            if orphans {
                toml_path = project_root / "jac.toml";
                pruned = _remove_npm_deps(toml_path, orphans);
            }
        }
        for name in removed {
            record_remove(project_root, name);
        }

        if pruned {
            console.print(
                "  Pruned " + str(len(pruned)) + " orphaned npm dep(s): " + ", ".join(
                    pruned
                ),
                style="muted"
            );
        } elif keep_deps {
            console.print("  --keep-deps: leaving npm deps in jac.toml", style="muted");
        }

        console.print(
            "Removed " + str(len(removed)) + " component(s): " + ", ".join(removed),
            style="bold green"
        );
    }

    return len(removed) > 0;
}

impl _suggest_close_matches(name: str, candidates: list, limit: int = 3) -> list {
    return difflib.get_close_matches(name, candidates, n=limit, cutoff=0.6);
}

impl upgrade_shadcn_components(
    config: any,
    names: list,
    style: str | None = None,
    base_color: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menu_accent: str | None = None
) -> bool {
    shadcn_config = _read_shadcn_config(config);
    if not shadcn_config {
        console.error(
            "No [jac-shadcn] section in jac.toml",
            hint="Run 'jac shadcn init' or 'jac create --use jac-shadcn' first."
        );
        return False;
    }
    project_root = Path(str(config.project_root));
    registry_url = shadcn_config.get("registry", "https://jac-shadcn.jaseci.org");

    # Decide which style to use AFTER any explicit override.
    target_style = style if style else shadcn_config.get("style", "nova");

    # Resolve which components to upgrade.
    lock = load_lockfile(project_root);
    installed = lock.get("components", {});
    if not installed {
        console.error(
            "No installed components recorded in jac-shadcn.lock",
            hint="Run 'jac shadcn add <name>' to install something first."
        );
        return False;
    }
    targets: list = list(names) if names else list(installed.keys());
    # Validate every requested name exists in the lockfile.
    missing: list = [
        n
        for n in targets
        if n not in installed
    ];
    if missing {
        suggestions: list = [];
        for m in missing {
            for s in _suggest_close_matches(m, list(installed.keys())) {
                suggestions.append(m + " -> " + s);
            }
        }
        hint_text = "Run 'jac shadcn list --installed-only' to see what's installed.";
        if suggestions {
            hint_text = "Did you mean: " + ", ".join(suggestions) + "?";
        }
        console.error("Not installed: " + ", ".join(missing), hint=hint_text);
        return False;
    }

    # Persist any explicitly-given theme overrides to jac.toml so future
    # installs (and a future `jac shadcn refresh-theme`) pick them up.
    updates: dict = {};
    if style and style != shadcn_config.get("style") {
        updates["style"] = style;
    }
    if base_color and base_color != shadcn_config.get("baseColor") {
        updates["baseColor"] = base_color;
    }
    if theme and theme != shadcn_config.get("theme") {
        updates["theme"] = theme;
    }
    if font and font != shadcn_config.get("font") {
        updates["font"] = font;
    }
    if radius and radius != shadcn_config.get("radius") {
        updates["radius"] = radius;
    }
    if menu_accent and menu_accent != shadcn_config.get("menuAccent") {
        updates["menuAccent"] = menu_accent;
    }
    if updates {
        toml_path = project_root / "jac.toml";
        doc = _load_toml(toml_path);
        if "jac-shadcn" in doc {
            for (k, v) in updates.items() {
                doc["jac-shadcn"][k] = v;
            }
            _save_toml(toml_path, doc);
            console.print(
                "  Updated [jac-shadcn]: " + ", ".join(
                    [k + "=" + str(v) for (k, v) in updates.items()]
                ),
                style="muted"
            );
            # Re-sync the app shell's body classes when style or baseColor
            # changed -- otherwise the CSS scope on .style-* / .base-color-*
            # won't match what the components expect.
            if "style" in updates or "baseColor" in updates {
                new_style = str(doc["jac-shadcn"].get("style", "nova"));
                new_base = str(doc["jac-shadcn"].get("baseColor", "neutral"));
                _patch_main_jac_theme_classes(project_root, new_style, new_base);
            }
        }
    }

    console.print(
        "\n Upgrading components (style: " + target_style + ")\n", style="bold cyan"
    );

    ui_dir = project_root / "components" / "ui";
    ui_dir.mkdir(parents=True, exist_ok=True);

    upgraded: list = [];
    new_npm_deps: dict = {};
    for name in targets {
        fetch_url = registry_url + "/component/" + name + "?style=" + target_style;
        comp_data = _fetch_json(fetch_url);
        if not comp_data or "error" in comp_data {
            err_msg = str(comp_data.get("error", "Unknown error"))
                if comp_data
                else "No response";
            console.error(
                "  x " + name + ": " + err_msg,
                hint="Check 'registry' in jac.toml or network connectivity."
            );
            continue;
        }
        raw_filename = comp_data.get("file", name + ".cl.jac");
        filename = _validate_component_filename(name, raw_filename);
        if filename is None {
            continue;
        }
        content = comp_data.get("content", "");
        out_path = ui_dir / filename;
        with open(out_path, "w") as f {
            f.write(content);
        }
        comp_npm = list(comp_data.get("npmDeps", []));
        for dep in comp_npm {
            if dep not in new_npm_deps {
                new_npm_deps[dep] = "*";
            }
        }
        comp_version = str(comp_data.get("version", DEFAULT_COMPONENT_VERSION));
        record_install(project_root, name, comp_version, comp_npm);
        upgraded.append(name);
        console.print(
            "  ~ " + name + "@" + comp_version + " (style=" + target_style + ")",
            style="green"
        );
    }

    if new_npm_deps {
        _update_npm_deps(config, new_npm_deps);
        console.print("\n  Updated jac.toml [dependencies.npm]", style="muted");
    }

    if upgraded {
        console.print(
            "\nUpgraded " + str(len(upgraded)) + " component(s).", style="bold green"
        );
    }
    return len(upgraded) > 0;
}

impl list_shadcn_components(config: any, installed_only: bool = False) -> bool {
    project_root = Path(str(config.project_root));
    lock = load_lockfile(project_root);
    installed: dict = lock.get("components", {});

    if installed_only {
        if not installed {
            console.print("No components installed yet.", style="muted");
            console.print("  Try: jac shadcn add button card", style="muted");
            return True;
        }
        console.print("\nInstalled (" + str(len(installed)) + ")", style="bold cyan");
        for name in sorted(list(installed.keys())) {
            entry = installed[name];
            ver = entry.get("version", "?");
            console.print("  + " + name + "@" + str(ver), style="green");
        }
        return True;
    }

    shadcn_config = _read_shadcn_config(config);
    if not shadcn_config {
        console.error(
            "No [jac-shadcn] section in jac.toml",
            hint="Run 'jac shadcn init <theme-url>' to set up shadcn here, or pass --installed-only."
        );
        return False;
    }
    registry_url = shadcn_config.get("registry", "https://jac-shadcn.jaseci.org");
    registry_data = _fetch_json(registry_url + "/registry");
    if not registry_data {
        console.error(
            "Could not fetch component registry from " + registry_url,
            hint="Pass --installed-only to skip the network call."
        );
        return False;
    }

    available: dict = registry_data.get("components", {});
    if not available {
        console.warning("Registry returned no components.");
        return False;
    }

    console.print(
        "\nAvailable (" + str(len(available)) + ", installed marked with *)\n",
        style="bold cyan"
    );
    for name in sorted(list(available.keys())) {
        if name in installed {
            ver = installed[name].get("version", "?");
            console.print(
                "  * " + name + " (installed @ " + str(ver) + ")", style="green"
            );
        } else {
            console.print("    " + name, style="muted");
        }
    }
    return True;
}

impl prune_orphan_deps(config: any) -> bool {
    project_root = Path(str(config.project_root));
    toml_path = project_root / "jac.toml";
    if not toml_path.exists() {
        console.error(
            "No jac.toml found at " + str(toml_path),
            hint="Run this from a project root."
        );
        return False;
    }
    lock = load_lockfile(project_root);
    installed: dict = lock.get("components", {});

    # Anything in [dependencies.npm] that no installed component declares
    # AND that was previously brought in by a jac-shadcn install is fair
    # game. We conservatively treat unknown deps as user-managed and leave
    # them alone -- only the union of "every npm dep ever declared by some
    # current install" is the universe of "shadcn-managed" deps. Subtract
    # that from current [dependencies.npm] keys and -- ah, that would catch
    # NOTHING since current installs hold their own deps. The orphan set is
    # exactly the OPPOSITE: deps that USED to be claimed but no installed
    # component still claims. We can't know "used to be claimed" without
    # a history; instead we treat "deps shadcn manages today" as those
    # currently held by any installed component, and prune any dep that is
    # NOT held by any installed component AND was previously installed by
    # shadcn (recorded somewhere). Without that history, prune is a no-op
    # unless we use the lockfile's snapshot.
    #
    # Practical algorithm: prune npm deps that match the SHAPE of shadcn-
    # added deps (i.e. version "*" or "^..." entries we set) AND aren't
    # in any installed component's npm_deps. Conservative; never touches
    # user-pinned deps that shadcn never managed.
    held: set = set();
    for (name, raw_entry) in installed.items() {
        deps = raw_entry["npm_deps"] if "npm_deps" in raw_entry else [];
        for d in deps {
            held.add(str(d));
        }
    }

    doc = _load_toml(toml_path);
    deps_table = doc.get("dependencies");
    if deps_table is None {
        console.print("Nothing to prune.", style="muted");
        return True;
    }
    npm_table = deps_table.get("npm");
    if npm_table is None {
        console.print("Nothing to prune.", style="muted");
        return True;
    }

    candidates: list = [];
    for key in list(npm_table.keys()) {
        # Only consider keys whose value is the shadcn-default "*" marker.
        # Anything else is presumed user-pinned and left alone.
        val = npm_table[key];
        if str(val) == "*" and key not in held {
            candidates.append(key);
        }
    }

    if not candidates {
        console.print("Nothing to prune -- jac.toml is clean.", style="muted");
        return True;
    }

    pruned = _remove_npm_deps(toml_path, candidates);
    console.print(
        "Pruned " + str(len(pruned)) + " orphaned npm dep(s): " + ", ".join(pruned),
        style="bold green"
    );
    return True;
}
