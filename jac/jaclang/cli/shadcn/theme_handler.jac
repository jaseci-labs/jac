import re;
import json as json_mod;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.shadcn.shadcn_handler {
    _registry_dir,
    load_registry,
    resolve_single_component
}

glob _DEFAULTS: dict = {
         "style": "nova",
         "baseColor": "neutral",
         "theme": "neutral",
         "font": "figtree",
         "radius": "default",
         "menuAccent": "subtle",
         "menuColor": "default"
     },
     _SHADCN_KEYS: list = [
         "style",
         "baseColor",
         "theme",
         "font",
         "radius",
         "menuAccent",
         "menuColor"
     ],
     RADII_MAP: dict = {
         "none": "0",
         "small": "0.45rem",
         "medium": "0.625rem",
         "large": "0.875rem"
     },
     FONT_DATA: dict = {
         "geist": {
             "family": "'Geist Variable', sans-serif",
             "npm": "@fontsource-variable/geist"
         },
         "inter": {
             "family": "'Inter Variable', sans-serif",
             "npm": "@fontsource-variable/inter"
         },
         "noto-sans": {
             "family": "'Noto Sans Variable', sans-serif",
             "npm": "@fontsource-variable/noto-sans"
         },
         "nunito-sans": {
             "family": "'Nunito Sans Variable', sans-serif",
             "npm": "@fontsource-variable/nunito-sans"
         },
         "figtree": {
             "family": "'Figtree Variable', sans-serif",
             "npm": "@fontsource-variable/figtree"
         },
         "roboto": {
             "family": "'Roboto Variable', sans-serif",
             "npm": "@fontsource-variable/roboto"
         },
         "raleway": {
             "family": "'Raleway Variable', sans-serif",
             "npm": "@fontsource-variable/raleway"
         },
         "dm-sans": {
             "family": "'DM Sans Variable', sans-serif",
             "npm": "@fontsource-variable/dm-sans"
         },
         "public-sans": {
             "family": "'Public Sans Variable', sans-serif",
             "npm": "@fontsource-variable/public-sans"
         },
         "outfit": {
             "family": "'Outfit Variable', sans-serif",
             "npm": "@fontsource-variable/outfit"
         },
         "jetbrains-mono": {
             "family": "'JetBrains Mono Variable', monospace",
             "npm": "@fontsource-variable/jetbrains-mono"
         },
         "geist-mono": {
             "family": "'Geist Mono Variable', monospace",
             "npm": "@fontsource-variable/geist-mono"
         }
     },
     THEME_INLINE_COLORS: list = [
         "sidebar-ring",
         "sidebar-border",
         "sidebar-accent-foreground",
         "sidebar-accent",
         "sidebar-primary-foreground",
         "sidebar-primary",
         "sidebar-foreground",
         "sidebar",
         "chart-5",
         "chart-4",
         "chart-3",
         "chart-2",
         "chart-1",
         "ring",
         "input",
         "border",
         "destructive",
         "accent-foreground",
         "accent",
         "muted-foreground",
         "muted",
         "secondary-foreground",
         "secondary",
         "primary-foreground",
         "primary",
         "popover-foreground",
         "popover",
         "card-foreground",
         "card",
         "foreground",
         "background"
     ],
     _UTILS_CONTENT: str = 'import from "clsx" { clsx }\nimport from "tailwind-merge" { twMerge }\n\ndef:pub cn(*inputs: any) -> str {\n    return twMerge(clsx(inputs));\n}\n';

def normalize_shadcn_config(raw: (dict | None)) -> dict {
    cfg: dict = {};
    cfg.update(_DEFAULTS);
    if raw {
        for key in _SHADCN_KEYS {
            if raw.get(key) {
                cfg[key] = raw[key];
            }
        }
    }
    return cfg;
}

def load_themes -> list {
    themes_path = _registry_dir() / "themes.json";
    if themes_path.is_file() {
        with open(themes_path, "r") as f {
            return json_mod.load(f);
        }
    }
    return [];
}

def find_theme(name: str) -> any {
    for theme in load_themes() {
        if theme["name"] == name {
            return theme;
        }
    }
    return None;
}

def resolve_css_vars(shadcn_config: dict) -> dict {
    base_color = find_theme(shadcn_config.get("baseColor", "neutral"));
    theme = find_theme(shadcn_config.get("theme", "neutral"));

    if not base_color or not theme {
        return {"light": {}, "dark": {}};
    }

    base_css = base_color.get("cssVars", {});
    theme_css = theme.get("cssVars", {});

    light_vars: dict = {};
    light_vars.update(base_css.get("light", {}));
    light_vars.update(theme_css.get("light", {}));

    dark_vars: dict = {};
    dark_vars.update(base_css.get("dark", {}));
    dark_vars.update(theme_css.get("dark", {}));

    if shadcn_config.get("menuAccent", "subtle") == "bold" {
        if light_vars.get("primary") {
            light_vars["accent"] = light_vars["primary"];
            light_vars["accent-foreground"] = light_vars.get("primary-foreground", "");
            light_vars["sidebar-accent"] = light_vars["primary"];
            light_vars["sidebar-accent-foreground"] = light_vars.get(
                "primary-foreground", ""
            );
        }
        if dark_vars.get("primary") {
            dark_vars["accent"] = dark_vars["primary"];
            dark_vars["accent-foreground"] = dark_vars.get("primary-foreground", "");
            dark_vars["sidebar-accent"] = dark_vars["primary"];
            dark_vars["sidebar-accent-foreground"] = dark_vars.get(
                "primary-foreground", ""
            );
        }
    }

    radius_name = shadcn_config.get("radius", "default");
    if radius_name and radius_name != "default" {
        radius_value = RADII_MAP.get(radius_name);
        if radius_value {
            light_vars["radius"] = radius_value;
            dark_vars["radius"] = radius_value;
        }
    }

    return {"light": light_vars, "dark": dark_vars};
}

def generate_global_css(font_value: str, css_vars: dict) -> str {
    font_info = FONT_DATA.get(font_value, FONT_DATA["figtree"]);
    font_family = font_info["family"];
    font_npm = font_info["npm"];

    light_vars = css_vars.get("light", {});
    dark_vars = css_vars.get("dark", {});

    lines: list = [
        '@import "tailwindcss";',
        '@import "tw-animate-css";',
        '@import "shadcn/tailwind.css";',
        '@import "' + font_npm + '";',
        "",
        "@custom-variant dark (&:is(.dark *));",
        ""
    ];

    lines.append(":root {");
    for k in light_vars {
        lines.append("    --" + str(k) + ": " + str(light_vars[k]) + ";");
    }
    lines.append("}");
    lines.append("");

    lines.append(".dark {");
    for k in dark_vars {
        lines.append("    --" + str(k) + ": " + str(dark_vars[k]) + ";");
    }
    lines.append("}");
    lines.append("");

    lines.append("@theme inline {");
    lines.append("    --font-sans: " + font_family + ";");
    for color_name in THEME_INLINE_COLORS {
        lines.append("    --color-" + color_name + ": var(--" + color_name + ");");
    }
    lines.append("    --radius-sm: calc(var(--radius) - 4px);");
    lines.append("    --radius-md: calc(var(--radius) - 2px);");
    lines.append("    --radius-lg: var(--radius);");
    lines.append("    --radius-xl: calc(var(--radius) + 4px);");
    lines.append("    --radius-2xl: calc(var(--radius) + 8px);");
    lines.append("    --radius-3xl: calc(var(--radius) + 12px);");
    lines.append("    --radius-4xl: calc(var(--radius) + 16px);");
    lines.append("}");
    lines.append("");

    lines.append("@layer base {");
    lines.append("    * {");
    lines.append("        @apply border-border outline-ring/50;");
    lines.append("    }");
    lines.append("    body {");
    lines.append("        @apply font-sans bg-background text-foreground;");
    lines.append("    }");
    lines.append("    html {");
    lines.append("        @apply font-sans;");
    lines.append("    }");
    lines.append("}");

    return "\n".join(lines);
}

def generate_starter_main_jac -> str {
    lines: list = [
        'import from ".components.ui.button" { Button }',
        'import from ".components.ui.card" {',
        '    Card, CardHeader, CardTitle, CardDescription, CardContent',
        '}',
        'import ".styles.global.css";',
        "",
        "def:pub app() -> JsxElement {",
        '    return <div className="min-h-screen bg-background text-foreground flex items-center justify-center p-6">',
        '        <Card className="w-full max-w-md">',
        "            <CardHeader>",
        "                <CardTitle>Welcome to {{name}}</CardTitle>",
        "                <CardDescription>A themed jac-shadcn starter.</CardDescription>",
        "            </CardHeader>",
        '            <CardContent className="flex gap-2">',
        "                <Button>Get started</Button>",
        '                <Button variant="outline">Docs</Button>',
        "            </CardContent>",
        "        </Card>",
        "    </div>;",
        "}",
        ""
    ];
    return "\n".join(lines);
}

def _render_shadcn_block(shadcn_config: dict) -> str {
    lines: list = ["[jac-shadcn]"];
    for key in _SHADCN_KEYS {
        lines.append(key + ' = "' + str(shadcn_config.get(key, _DEFAULTS[key])) + '"');
    }
    return "\n".join(lines);
}

def set_shadcn_section(toml_path: any, shadcn_config: dict) {
    path = Path(str(toml_path));
    content = path.read_text() if path.exists() else "";
    block = _render_shadcn_block(shadcn_config);

    marker = "[jac-shadcn]";
    idx = content.find(marker);
    if idx >= 0 {
        rest_idx = content.find("\n[", idx + len(marker));
        tail = content[rest_idx:] if rest_idx >= 0 else "\n";
        content = content[:idx] + block + tail;
    } else {
        content = (content.rstrip() + "\n\n" + block + "\n")
            if content.strip()
            else (block + "\n");
    }
    path.write_text(content);
}

def _toml_key(key: str) -> str {
    return key if re.match(r'^[A-Za-z0-9_-]+$', key) else '"' + key + '"';
}

def _patch_npm_deps(toml_path: any, npm_deps: dict) -> None {
    if not npm_deps {
        return;
    }
    path = Path(str(toml_path));
    content = path.read_text();
    marker = "[dependencies.npm]";
    for key in npm_deps {
        if re.search(
            r'(?m)^\s*' + _toml_key(key).replace('.', r'\.') + r'\s*=', content
        ) {
            continue;
        }
        idx = content.find(marker);
        if idx >= 0 {
            insert_pos = idx + len(marker);
            line = "\n" + _toml_key(key) + ' = "' + str(npm_deps[key]) + '"';
            content = content[:insert_pos] + line + content[insert_pos:];
        }
    }
    path.write_text(content);
}

def _ensure_vite_tailwind(toml_path: any) -> None {
    path = Path(str(toml_path));
    if not path.exists() {
        return;
    }
    content = path.read_text();
    if "[client.vite]" in content {
        return;
    }
    block = '[client.vite]\nplugins = ["tailwindcss()"]\n' + 'lib_imports = ["import tailwindcss from \'@tailwindcss/vite\'"]\n';
    path.write_text(content.rstrip() + "\n\n" + block);
}

def _install_component(ui_dir: any, name: str, style: str) -> list {
    comp = resolve_single_component(name, style);
    if not comp or "error" in comp {
        return [];
    }

    out_name = str(comp.get("file", name + ".jac")).replace("-", "_");
    out_path = Path(str(ui_dir)) / out_name;
    out_path.write_text(comp.get("content", ""));
    return comp.get("npmDeps", []);
}

def materialize_themed_starter(
    project_root: any, project_name: str, shadcn_config: dict
) -> bool {
    pr = Path(str(project_root));
    style = shadcn_config.get("style", "nova");
    font = shadcn_config.get("font", "figtree");

    ui_dir = pr / "components" / "ui";
    ui_dir.mkdir(parents=True, exist_ok=True);

    npm_deps: dict = {
        "tailwindcss": "^4.1.17",
        "@tailwindcss/vite": "^4.1.17",
        "clsx": "^2.1.1",
        "tailwind-merge": "^3.5.0",
        "tw-animate-css": "^1.4.0",
        "shadcn": "^3.8.5"
    };
    npm_deps[FONT_DATA.get(font, FONT_DATA["figtree"])["npm"]] = "*";

    for name in ["button", "card"] {
        for dep in _install_component(ui_dir, name, style) {
            if dep not in npm_deps {
                npm_deps[dep] = "*";
            }
        }
    }

    lib_dir = pr / "lib";
    lib_dir.mkdir(parents=True, exist_ok=True);
    (lib_dir / "utils.jac").write_text(_UTILS_CONTENT);

    styles_dir = pr / "styles";
    styles_dir.mkdir(parents=True, exist_ok=True);
    (styles_dir / "global.css").write_text(
        generate_global_css(font, resolve_css_vars(shadcn_config))
    );

    (pr / "main.jac").write_text(
        generate_starter_main_jac().replace("{{name}}", project_name)
    );

    toml_path = pr / "jac.toml";
    set_shadcn_section(toml_path, shadcn_config);
    _patch_npm_deps(toml_path, npm_deps);
    _ensure_vite_tailwind(toml_path);

    console.print("");
    console.print(
        "  Themed starter ready (style: " + style + ", theme: " + shadcn_config.get(
            "theme", "neutral"
        ) + ", font: " + font + ")",
        style="bold green"
    );
    console.print(
        "  Add more components with: jac install --shadcn <name>", style="muted"
    );
    return True;
}

def retheme_project(config: any, overrides: dict) -> bool {
    if config is None or config.project_root is None {
        console.error(
            "No jac.toml found", hint="Run this inside a jac-shadcn project."
        );
        return False;
    }

    raw = None;
    if config?._raw_data and config._raw_data is not None {
        raw = config._raw_data.get("jac-shadcn");
    }
    current = normalize_shadcn_config(raw);
    old_style = current.get("style", "nova");

    merged: dict = {};
    merged.update(current);
    for key in _SHADCN_KEYS {
        if overrides.get(key) is not None {
            merged[key] = overrides[key];
        }
    }
    new_style = merged.get("style", "nova");

    project_root = Path(str(config.project_root));
    toml_path = project_root / "jac.toml";

    set_shadcn_section(toml_path, merged);
    styles_dir = project_root / "styles";
    styles_dir.mkdir(parents=True, exist_ok=True);
    (styles_dir / "global.css").write_text(
        generate_global_css(merged.get("font", "figtree"), resolve_css_vars(merged))
    );
    _patch_npm_deps(
        toml_path,
        {
            FONT_DATA.get(merged.get("font", "figtree"), FONT_DATA["figtree"])["npm"]: "*",
            "tailwindcss": "^4.1.17",
            "@tailwindcss/vite": "^4.1.17",
            "shadcn": "^3.8.5"
        }
    );
    _ensure_vite_tailwind(toml_path);

    console.print(
        "  Retheme (base: " + merged.get("baseColor", "neutral") + ", theme: " + merged.get(
            "theme", "neutral"
        ) + ", font: " + merged.get("font", "figtree") + ")",
        style="bold cyan"
    );
    console.print("  + styles/global.css", style="green");

    if new_style != old_style {
        restyled = 0;
        ui_dir = project_root / "components" / "ui";
        components_meta: dict = load_registry().get("components", {});
        stem_to_key: dict = {};
        for key in components_meta {
            reg_file = str(components_meta[key].get("file", str(key) + ".jac"));
            reg_stem = reg_file.replace(".cl.jac", "").replace(".jac", "").replace(
                "-", "_"
            );
            stem_to_key[reg_stem] = key;
        }
        if ui_dir.exists() {
            for f in sorted(list(ui_dir.iterdir())) {
                if not f.name.endswith(".jac") {
                    continue;
                }
                stem = f.name.replace(".cl.jac", "").replace(".jac", "");
                comp = resolve_single_component(stem_to_key.get(stem, stem), new_style);
                if not comp or "error" in comp {
                    continue;
                }
                f.write_text(comp.get("content", ""));
                restyled += 1;
            }
        }
        console.print(
            "  + restyled " + str(restyled) + " component(s) -> " + new_style,
            style="green"
        );
    }

    return True;
}
