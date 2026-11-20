import shutil;

import os;

import from pathlib { Path }

def _inject_missing(deps: dict[str, any], required: dict[str, str]) -> dict[str, any];

def _migrate_legacy_meta_packages(
    jac_config: any, npm_deps: dict[str, any], npm_dev_deps: dict[str, any]
) -> tuple[dict[str, any], dict[str, any], bool];

def _clear_node_modules(client_dir: Path | None);

impl JacClientConfig.get_plugin_name(self: JacClientConfig) -> str {
    return "client";
}

impl JacClientConfig.get_default_config(self: JacClientConfig) -> dict[str, any] {
    return {
        'api': {'base_url': ''},
        'base_path': '/',
        'vite': {
            'plugins': [],
            'lib_imports': [],
            'define': {},
            'build': {},
            'server': {},
            'resolve': {}
        },
        'ts': {'compilerOptions': {}, 'include': [], 'exclude': []},
        'configs': {},
        'paths': {},
        'routing': {'auth_redirect': '/login'},
        'assets': {'dir': '', 'custom_extensions': []},
        'npm': {},
        'package': {
            'name': '',
            'version': '1.0.0',
            'description': '',
            'dependencies': {},
            'devDependencies': {}
        }
    };
}

impl JacClientConfig.load(self: JacClientConfig) -> dict[str, any] {
    target_app = self.get_jac_config().app_for_target(self.entry_path);
    app_name = target_app.name if target_app is not None else '';
    cached = self._config;
    if cached is not None and self._config_app == app_name {
        return cached;
    }
    self._config_app = app_name;
    default_config = self.get_default_config();
    jac_config = self.get_jac_config();

    client_config = self.effective_jac_config().get_plugin_config('client');

    npm_deps = jac_config.get_plugin_deps('npm');
    target_scoped_deps: dict[str, str] = {};
    app_dev_deps: dict[str, str] = {};
    for (dep_name, dep_version, _origin, dep_is_dev) in app_npm_deps(jac_config) {
        if dep_is_dev {
            app_dev_deps[dep_name] = dep_version;
        } else {
            target_scoped_deps[dep_name] = dep_version;
        }
    }

    npm_plugin_deps: dict[str, any] = dict(
        jac_config.plugin_dependencies.get('npm', {})
    );
    dev_section = npm_plugin_deps.get('dev', {});
    npm_dev_deps: dict[str, any] = dict(dev_section)
        if isinstance(dev_section, dict)
        else {};

    if 'client' in jac_config.plugins {
        (npm_deps, npm_dev_deps, migrated) = _migrate_legacy_meta_packages(
            jac_config, npm_deps, npm_dev_deps
        );
        if migrated {
            _clear_node_modules(self.get_jac_config().get_client_dir());
        }
    }

    npm_deps = _inject_missing(
        npm_deps, {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS}
    );
    npm_dev_deps = _inject_missing(npm_dev_deps, CORE_DEV_DEPS);
    npm_dev_deps = {** npm_dev_deps, ** app_dev_deps};
    merged_npm_deps = {** npm_deps, ** target_scoped_deps};
    for (dep_name, dep_version) in _package_npm_deps(jac_config).items() {
        merged_npm_deps.setdefault(dep_name, dep_version);
    }

    vite_settings: dict[str, any] = dict(client_config.get('vite', {}));
    for (key, value) in eco_vite_settings(jac_config, self.entry_path).items() {
        held = vite_settings.get(key);
        if isinstance(value, list) {
            vite_settings[key] = list(held or [])
                + [
                    v
                    for v in value
                    if v not in (held or [])
                ];
        } elif isinstance(value, dict) {
            merged_value = dict(value);
            merged_value.update(held or {});
            vite_settings[key] = merged_value;
        } elif key not in vite_settings {
            vite_settings[key] = value;
        }
    }
    user_config: dict[str, any] = {
        'api': client_config.get('api', {}),
        'base_path': client_config.get('base_path', '/'),
        'vite': vite_settings,
        'ts': client_config.get('ts', {}),
        'configs': client_config.get('configs', {}),
        'paths': client_config.get('paths', {}),
        'routing': client_config.get('routing', {}),
        'npm': client_config.get('npm', {}),
        'pwa': client_config.get('pwa', {}),
        'assets': client_config.get('assets', {}),
        'package': {
            'name': _npm_package_name(jac_config.project.name),
            'version': jac_config.project.version,
            'description': jac_config.project.description,
            'dependencies': merged_npm_deps,
            'devDependencies': npm_dev_deps
        }
    };
    merged = deep_merge(default_config, user_config);
    self._config = merged;
    return merged;
}

def _package_npm_deps(jac_config: any) -> dict[str, str];

def _npm_package_name(name: str) -> str;

impl JacClientConfig.get_package_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('package', {});
}

impl JacClientConfig.get_api_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('api', {});
}

impl JacClientConfig.get_base_path(self: JacClientConfig) -> str {
    config = self.load();
    return str(config.get('base_path', '/'));
}

impl JacClientConfig.get_vite_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('vite', {});
}

impl JacClientConfig.get_ts_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('ts', {});
}

impl JacClientConfig.get_configs(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('configs', {});
}

impl JacClientConfig.get_npm_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('npm', {});
}

impl JacClientConfig.save(self: JacClientConfig) -> None {
    jac_config = self.get_jac_config();
    jac_config.save();
}

impl JacClientConfig.add_dependency(
    self: JacClientConfig, name: str, version: str, is_dev: bool = False
) -> None {
    jac_config = self.get_jac_config();
    jac_config.add_dependency(name, version, dev=is_dev, dep_type="npm");

    self.invalidate();
}

impl JacClientConfig.remove_dependency(
    self: JacClientConfig, name: str, is_dev: bool = False
) -> bool {
    jac_config = self.get_jac_config();
    result = jac_config.remove_dependency(name, dev=is_dev, dep_type="npm");

    self.invalidate();
    return result;
}

impl JacClientConfig.get_paths_config(self: JacClientConfig) -> dict[str, str] {
    config = self.load();
    return config.get('paths', {});
}

impl JacClientConfig.get_pwa_config(self: JacClientConfig) -> dict[str, any] {
    config = self.load();
    return config.get('pwa', {});
}

impl JacClientConfig.get_assets_config(self: JacClientConfig) -> dict[str, any] {
    return client_assets_config(self.get_jac_config(), self.entry_path);
}

impl JacClientConfig.get_asset_extensions(self: JacClientConfig) -> set[str] {
    return set(self.get_assets_config().get('custom_extensions', []));
}

impl JacClientConfig.get_assets_dir(
    self: JacClientConfig, entry_path: str = ""
) -> Path {
    return client_assets_dir(
        self.get_jac_config(),
        self.project_dir or Path.cwd(),
        entry_path or self.entry_path
    );
}

impl JacClientConfig.get_app_root(self: JacClientConfig, entry_path: str = "") -> Path {
    return client_app_root(
        self.get_jac_config(),
        self.project_dir or Path.cwd(),
        entry_path or self.entry_path
    );
}

impl JacClientConfig.get_public_dirs(
    self: JacClientConfig, entry_path: str = ""
) -> list[Path] {
    project_dir = self.project_dir or Path.cwd();
    app_root = self.get_app_root(entry_path);
    dirs: list[Path] = [];
    for candidate in (app_root / 'public', project_dir / 'public') {
        if candidate.is_dir()
            and candidate.resolve() not in [d.resolve() for d in dirs] {
            dirs.append(candidate);
        }
    }
    return dirs;
}

impl JacClientConfig.get_seo_config(
    self: JacClientConfig, entry_path: str = ""
) -> dict[str, any] {
    return client_seo_config(self.get_jac_config(), entry_path or self.entry_path);
}

impl JacClientConfig.is_pwa_enabled(self: JacClientConfig) -> bool {
    pwa_config = self.get_pwa_config();

    return len(pwa_config) > 0;
}

impl JacClientConfig.get_react_native_config(self: JacClientConfig) -> dict[str, any] {
    client_config = self.effective_jac_config().get_plugin_config("client");
    section = client_config.get("react_native", {});
    return section if isinstance(section, dict) else {};
}

impl _inject_missing(deps: dict[str, any], required: dict[str, str]) -> dict[str, any] {
    merged = dict(deps);
    for (name, version) in required.items() {
        if name not in merged {
            merged[name] = version;
        }
    }
    return merged;
}

impl _clear_node_modules(client_dir: Path | None) {
    if client_dir is not None {
        node_modules: Path = client_dir / 'node_modules';
        if node_modules.exists() {
            shutil.rmtree(node_modules);
            console.print("  Reinstalling dependencies...\n");
        }
    }
}

impl _package_npm_deps(jac_config: any) -> dict[str, str] {
    if jac_config.project_root is None {
        return {};
    }
    try {
        lock = load_lock(jac_config);
    } except InstallError {
        return {};
    }
    return {
        name: spec for (name, spec, _owner) in package_npm_requirements(lock, False)
    };
}

impl _npm_package_name(name: str) -> str {
    return f"@{name}" if "/" in name and not name.startswith("@") else name;
}

impl _migrate_legacy_meta_packages(
    jac_config: any, npm_deps: dict[str, any], npm_dev_deps: dict[str, any]
) -> tuple[dict[str, any], dict[str, any], bool] {
    migrated = False;

    if 'jac-client-node' in npm_deps {
        console.warning(
            "Migrating from jac-client-node meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('jac-client-node', dev=False, dep_type='npm');
        del npm_deps['jac-client-node'];

        all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
        for (name, version) in all_runtime.items() {
            if name not in npm_deps {
                jac_config.add_dependency(name, version, dev=False, dep_type='npm');
                npm_deps[name] = version;
            }
        }
        console.success("Replaced jac-client-node with individual packages");
        migrated = True;
    }

    if '@jac-client/dev-deps' in npm_dev_deps {
        console.warning(
            "Migrating from @jac-client/dev-deps meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('@jac-client/dev-deps', dev=True, dep_type='npm');
        del npm_dev_deps['@jac-client/dev-deps'];
        for (name, version) in CORE_DEV_DEPS.items() {
            if name not in npm_dev_deps {
                jac_config.add_dependency(name, version, dev=True, dep_type='npm');
                npm_dev_deps[name] = version;
            }
        }
        console.success("Replaced @jac-client/dev-deps with individual packages");
        migrated = True;
    }

    if migrated {
        jac_config.save();
    }
    return (npm_deps, npm_dev_deps, migrated);
}

glob _JAC_SUPPLIED_VITE_PACKAGES: set[str] = {
         "vite",
         "@vitejs/plugin-react",
         "@vitejs/plugin-react-swc",
         "@jac/vite"
     };

impl eco_vite_settings(jac_config: any, entry_path: str) -> dict[str, any] {
    import re;
    if jac_config is None or jac_config.project_root is None {
        return {};
    }
    raw = jac_config._raw_data if isinstance(jac_config._raw_data, dict) else {};
    app = jac_config.app_for_target(entry_path) if entry_path else None;
    if app is None {
        try {
            app = jac_config.resolve_app("");
        } except Exception {
            app = None;
        }
    }
    tree = app_npm_tree(raw, app) if app is not None else "";
    if not tree {
        for candidate in jac_config.apps.values() {
            tree = app_npm_tree(raw, candidate);
            if tree {
                break;
            }
        }
    }
    if not tree {
        return {};
    }
    config_path = Path(str(jac_config.project_root)) / "eco" / tree / "vite.config.ts";
    if not config_path.is_file() {
        config_path = Path(str(jac_config.project_root))
            / "eco"
            / tree
            / "vite.config.js";
    }
    if not config_path.is_file() {
        return {};
    }
    try {
        text = config_path.read_text(encoding="utf-8");
    } except OSError {
        return {};
    }
    return _parse_vite_config(text);
}

impl _parse_vite_config(text: str) -> dict[str, any] {
    import re;
    out: dict[str, any] = {};
    imported: dict[str, str] = {};
    lib_imports: list[str] = [];
    for hit in re.finditer(
        r'import\s+(.+?)\s+from\s+[\x22\x27]([^\x22\x27]+)[\x22\x27];?', text, re.DOTALL
    ) {
        (clause, package) = (hit.group(1).strip(), hit.group(2));
        for name in _imported_names(clause) {
            imported[name] = package;
        }
        if package not in _JAC_SUPPLIED_VITE_PACKAGES {
            lib_imports.append(f'import {clause} from "{package}";');
        }
    }
    plugins: list[str] = [];
    plugins_hit = re.search(r'plugins:\s*\[', text);
    if plugins_hit {
        for call in _split_top_level(_bracketed(text, plugins_hit.end() - 1)) {
            name = call.split("(")[0].strip();
            if imported.get(name, "") in _JAC_SUPPLIED_VITE_PACKAGES {
                continue;
            }
            plugins.append(call);
        }
    }
    if lib_imports {
        out["lib_imports"] = lib_imports;
    }
    if plugins {
        out["plugins"] = plugins;
    }
    aliases: dict[str, str] = {};
    for hit in re.finditer(
        r'find:\s*(?:/\^?([^/$]+)\$?/|[\x22\x27]([^\x22\x27]+)[\x22\x27])\s*,\s*replacement:\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]',
        text
    ) {
        aliases[hit.group(1) or hit.group(2)] = hit.group(3);
    }
    if aliases {
        out["alias_packages"] = aliases;
    }
    dedupe_hit = re.search(r'dedupe:\s*\[', text);
    if dedupe_hit {
        names = [
            n.strip().strip('"').strip("'")
            for n in _split_top_level(_bracketed(text, dedupe_hit.end() - 1))
        ];
        if names {
            out["resolve"] = {"dedupe": names};
        }
    }
    return out;
}

impl _imported_names(clause: str) -> list[str] {
    import re;
    names: list[str] = [];
    braced = re.search(r'\{(.*)\}', clause, re.DOTALL);
    if braced {
        for part in braced.group(1).split(",") {
            piece = part.strip();
            if piece {
                names.append(piece.split(" as ")[-1].strip());
            }
        }
        clause = clause[:braced.start()] + clause[braced.end():];
    }
    for piece in clause.replace("* as ", "").split(",") {
        name = piece.strip();
        if name {
            names.append(name);
        }
    }
    return names;
}

impl _bracketed(text: str, open_at: int) -> str {
    depth = 0;
    for i in range(open_at, len(text)) {
        ch = text[i];
        if ch in "([{" {
            depth += 1;
        } elif ch in ")]}" {
            depth -= 1;
            if depth == 0 {
                return text[open_at + 1:i];
            }
        }
    }
    return text[open_at + 1:];
}

impl _split_top_level(text: str) -> list[str] {
    items: list[str] = [];
    depth = 0;
    held = "";
    for ch in text {
        if ch in "([{" {
            depth += 1;
        } elif ch in ")]}" {
            depth -= 1;
        }
        if ch == "," and depth == 0 {
            if held.strip() {
                items.append(held.strip());
            }
            held = "";
        } else {
            held += ch;
        }
    }
    if held.strip() {
        items.append(held.strip());
    }
    return items;
}
