import from pathlib { Path }

glob _LIGHT_THEME: dict[str, str] = {
         "primary": "#2563eb",
         "onPrimary": "#ffffff",
         "secondary": "#4f46e5",
         "onSecondary": "#ffffff",
         "tertiary": "#0f766e",
         "onTertiary": "#ffffff",
         "muted": "#64748b",
         "onMuted": "#ffffff",
         "background": "#ffffff",
         "onBackground": "#111827",
         "surface": "#f8fafc",
         "onSurface": "#111827",
         "success": "#16a34a",
         "onSuccess": "#ffffff",
         "info": "#0284c7",
         "onInfo": "#ffffff",
         "warning": "#d97706",
         "onWarning": "#111827",
         "danger": "#dc2626",
         "onDanger": "#ffffff",
         "softPrimary": "#dbeafe",
         "onSoftPrimary": "#1e3a8a",
         "softSecondary": "#e0e7ff",
         "onSoftSecondary": "#312e81",
         "softTertiary": "#ccfbf1",
         "onSoftTertiary": "#134e4a",
         "softMuted": "#e2e8f0",
         "onSoftMuted": "#334155",
         "softSuccess": "#dcfce7",
         "onSoftSuccess": "#14532d",
         "softInfo": "#e0f2fe",
         "onSoftInfo": "#075985",
         "softWarning": "#fef3c7",
         "onSoftWarning": "#78350f",
         "softDanger": "#fee2e2",
         "onSoftDanger": "#7f1d1d"
     },
     _LIGHT_RADIUS: int = 8;

impl escape_kotlin(value: str) -> str {
    return (
        value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace(
            '$', '\\$'
        )
    );
}

impl escape_android_xml(value: str) -> str {
    return (
        value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace(
            '"', '&quot;'
        ).replace(
            "'", "\\'"
        )
    );
}

impl package_to_path(package_name: str) -> str {
    return package_name.replace('.', '/');
}

impl android_color_literal(hex: str) -> str {
    raw = hex.strip().lstrip('#');
    if len(raw) == 6 {
        argb = f"FF{raw.upper()}";
    } elif len(raw) == 8 {
        argb = f"{raw[6:8].upper()}{raw[0:6].upper()}";
    } else {
        argb = raw.upper();
    }
    return f"Color(0x{argb})";
}

impl emit_jac_design -> str {
    lines: list[str] = [
        "object JacDesign {",
        '    var name by mutableStateOf("light")',
        "        private set"
    ];
    for (token, hex_val) in _LIGHT_THEME.items() {
        lines.append(
            f"    var {token} by mutableStateOf({android_color_literal(hex_val)})"
        );
        lines.append("        private set");
    }
    lines.append(f"    var radius by mutableStateOf({_LIGHT_RADIUS}.dp)");
    lines.append("        private set");
    lines.append("    fun applyTheme(themeName: String) {");
    lines.append(
        '        val theme = JacThemeModule.themes.firstOrNull { it.name == themeName } '
            + "?: JacThemeModule.themes.first { it.name == JacThemeModule.defaultTheme }"
    );
    lines.append("        name = theme.name");
    for token in _LIGHT_THEME.keys() {
        lit = android_color_literal(_LIGHT_THEME[token]);
        lines.append(f'        {token} = theme.colors["{token}"] ?: {lit}');
    }
    lines.append("        radius = theme.radius");
    lines.append("    }");
    lines.append("}");
    return '\n'.join(lines) + '\n';
}

def _theme_color_map_entries -> str {
    entries: list[str] = [];
    for (token, hex_val) in _LIGHT_THEME.items() {
        entries.append(f'            "{token}" to {android_color_literal(hex_val)},');
    }
    return '\n'.join(entries);
}

def _tpl_dir -> str {
    import os;
    import jaclang;
    return os.path.join(
        os.path.dirname(jaclang.__file__),
        "compiler",
        "passes",
        "compose",
        "gradle_templates"
    );
}

glob _TPL_CACHE: dict[str, str] = {};

def _tpl(name: str, vars: dict[str, str]) -> str {
    if name not in _TPL_CACHE {
        import os;
        with open(os.path.join(_tpl_dir(), name), encoding="utf-8") as f {
            _TPL_CACHE[name] = f.read();
        }
    }
    text = _TPL_CACHE[name];
    for (key, value) in vars.items() {
        text = text.replace("{{" + key + "}}", value);
    }
    return text;
}

def _root_gradle -> str {
    return _tpl("root.gradle.kts", {});
}

def _gradle_properties -> str {
    return _tpl("gradle.properties", {});
}

def _settings_gradle(dev: bool = False) -> str {
    return _tpl(
        "settings.gradle.kts", {"hot_include": '\ninclude(":hot")' if dev else ""}
    );
}

def _styles_xml -> str {
    return _tpl("styles.xml", {});
}

def _hot_manifest -> str {
    return _tpl("hot_manifest.xml", {});
}

def _strings_xml(app_name: str) -> str {
    return _tpl("strings.xml", {"app_name": escape_android_xml(app_name)});
}

def _android_manifest(app_name: str, dev: bool = False) -> str {
    name = "AndroidManifest.dev.xml" if dev else "AndroidManifest.xml";
    return _tpl(name, {"label": escape_android_xml(app_name)});
}

def _module_gradle(android_plugin: str, package_name: str, default_config: str) -> str {
    return _tpl(
        "module.gradle.kts",
        {
            "android_plugin": android_plugin,
            "namespace": escape_kotlin(package_name),
            "default_config": default_config
        }
    );
}

def _app_gradle(package_name: str) -> str {
    pkg = escape_kotlin(package_name);
    default_config = (
        f'    defaultConfig {{\n'
        f'        applicationId = "{pkg}"\n'
        f'        minSdk = 26\n'
        f'        targetSdk = 36\n'
        f'        versionCode = 1\n'
        f'        versionName = "0.1.0"\n'
        f'    }}'
    );
    return _module_gradle("com.android.application", package_name, default_config);
}

def _hot_gradle(package_name: str) -> str {
    default_config = '    defaultConfig {\n        minSdk = 26\n    }';
    return _module_gradle("com.android.library", package_name, default_config);
}

def _main_activity(package_name: str) -> str {
    return _tpl("MainActivity.kt", {"package_name": package_name});
}

def _jac_routing(package_name: str, routes: list[str]) -> str {
    effective = routes or ["/"];
    route_lines = '\n'.join([f'    "{escape_kotlin(p)}",' for p in effective]);
    initial = effective[0];
    deep_lines = '\n'.join(
        [f'    "jac-dev://generated{"/" if p == "/" else p}",' for p in effective]
    );
    section_lines = '\n'.join(
        [f'    "{escape_kotlin(p)}" to listOf(),' for p in effective]
    );
    return _tpl(
        "JacRouting.kt",
        {
            "package_name": package_name,
            "initial": escape_kotlin(initial),
            "route_lines": route_lines,
            "section_lines": section_lines,
            "deep_lines": deep_lines
        }
    );
}

def _jac_environment(package_name: str, backend_url: str) -> str {
    return _tpl(
        "JacEnvironment.kt",
        {"package_name": package_name, "backend_url": escape_kotlin(backend_url)}
    );
}

def _jac_theme(package_name: str) -> str {
    return _tpl(
        "JacTheme.kt",
        {
            "package_name": package_name,
            "colors": _theme_color_map_entries(),
            "radius": str(_LIGHT_RADIUS)
        }
    );
}

def _jac_dev_entry(package_name: str) -> str {
    return _tpl("JacDevEntry.kt", {"package_name": package_name});
}

def _jac_dev_host_activity(package_name: str) -> str {
    return _tpl("JacDevHostActivity.kt", {"package_name": package_name});
}

impl build_gradle_scaffold(
    package_name: str,
    app_name: str,
    backend_url: str,
    routes: list[str],
    dev: bool = False
) -> dict[str, str] {
    pkg_path = package_to_path(package_name);
    base_root = f"app/src/main/java/{pkg_path}";
    hot_root = f"hot/src/main/java/{pkg_path}";
    effective_routes = routes or ["/"];
    infra_files: dict[str, str] = {
        "MainActivity.kt": _main_activity(package_name),
        "JacRouting.kt": _jac_routing(package_name, effective_routes),
        "JacEnvironment.kt": _jac_environment(package_name, backend_url),
        "JacTheme.kt": _jac_theme(package_name)
    };
    files: dict[str, str] = {
        "build.gradle.kts": _root_gradle(),
        "gradle.properties": _gradle_properties(),
        "app/build.gradle.kts": _app_gradle(package_name),
        "app/src/main/res/values/styles.xml": _styles_xml(),
        "app/src/main/res/values/strings.xml": _strings_xml(app_name)
    };
    if dev {
        files["settings.gradle.kts"] = _settings_gradle(dev=True);
        files["app/src/main/AndroidManifest.xml"] = _android_manifest(
            app_name, dev=True
        );
        files["hot/build.gradle.kts"] = _hot_gradle(package_name);
        files["hot/src/main/AndroidManifest.xml"] = _hot_manifest();
        files[f"{base_root}/JacDevHostActivity.kt"] = _jac_dev_host_activity(
            package_name
        );
        for (name, content) in infra_files.items() {
            files[f"{hot_root}/{name}"] = content;
        }
        files[f"{hot_root}/JacDevEntry.kt"] = _jac_dev_entry(package_name);
    } else {
        files["settings.gradle.kts"] = _settings_gradle(dev=False);
        files["app/src/main/AndroidManifest.xml"] = _android_manifest(
            app_name, dev=False
        );
        for (name, content) in infra_files.items() {
            files[f"{base_root}/{name}"] = content;
        }
    }
    return files;
}
