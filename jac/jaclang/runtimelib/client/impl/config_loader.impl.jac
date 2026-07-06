import shutil;
import os;
import from jaclang.cli.console { console }
import from pathlib { Path }
import from jaclang.project.plugin_config { deep_merge }

glob CORE_RUNTIME_DEPS: dict[str, str] = {
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0"
     },
     OPTIONAL_RUNTIME_DEPS: dict[str, str] = {
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     CORE_DEV_DEPS: dict[str, str] = {
         "vite": "^6.4.1",
         "@vitejs/plugin-react": "^4.2.1",
         "typescript": "^5.3.3",
         "@types/react": "^18.2.0",
         "@types/react-dom": "^18.2.0"
     },
     LEGACY_META_PACKAGES = {"jac-client-node", "@jac-client/dev-deps"};

def _ensure_dependencies(
    jac_config: any,
    deps: dict,
    required: dict[str, str],
    is_dev: bool,
    description: str
) -> tuple[dict, bool] {
    needs_reinstall = False;
    for (name, version) in required.items() {
        if name not in deps {
            console.warning(
                f"Missing required {'dev ' if is_dev else ''}dependency: {name}"
            );
            console.print(f"  {description}");
            jac_config.add_dependency(name, version, dev=is_dev, dep_type='npm');
            deps = {name: version, ** deps};
            console.success(f"Added {name}@{version} to jac.toml");
            needs_reinstall = True;
        }
    }
    if needs_reinstall {
        jac_config.save();
    }
    return (deps, needs_reinstall);
}

def _migrate_legacy_meta_packages(
    jac_config: any, npm_deps: dict, npm_dev_deps: dict
) -> tuple[dict, dict, bool] {
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

def _clear_node_modules(client_dir: Path | None) {
    if client_dir is not None {
        node_modules: Path = client_dir / 'node_modules';
        if node_modules.exists() {
            shutil.rmtree(node_modules);
            console.print("  Reinstalling dependencies...\n");
        }
    }
}

def _resolve_client_target(client_config: dict) -> str {
    raw = str(client_config.get("target", "") or "").strip();
    if raw == "" {
        raw = str(os.environ.get("JAC_CLIENT_TARGET", "") or "").strip();
    }
    if raw == "" {
        return "web";
    }
    normalized = raw.lower().replace("-", "_");
    if normalized == "rn" {
        return "react_native";
    }
    if normalized == "reactnative" {
        return "react_native";
    }
    return normalized;
}

def _get_target_scoped_npm_deps(jac_config: any, target_name: str) -> dict[str, str] {
    npm_plugin_deps: dict = dict(jac_config.plugin_dependencies.get("npm", {}));
    deps: dict[str, str] = {};
    key1 = str(target_name or "").strip();
    key2 = key1.replace("_", "-");
    for key in [key1, key2] {
        if key == "" {
            continue;
        }
        section = npm_plugin_deps.get(key, {});
        if isinstance(section, dict) {
            for (name, version) in section.items() {
                if isinstance(version, str) {
                    deps[name] = version;
                }
            }
        }
    }
    return deps;
}

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
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    jac_config = self.get_jac_config();

    client_config = jac_config.get_plugin_config('client');
    target_name = _resolve_client_target(client_config);

    npm_deps = jac_config.get_plugin_deps('npm');
    target_scoped_npm_deps = _get_target_scoped_npm_deps(jac_config, target_name);

    npm_plugin_deps: dict = dict(jac_config.plugin_dependencies.get('npm', {}));
    dev_section = npm_plugin_deps.get('dev', {});
    npm_dev_deps: dict = dict(dev_section) if isinstance(dev_section, dict) else {};

    if 'client' in jac_config.plugins {
        (npm_deps, npm_dev_deps, migrated) = _migrate_legacy_meta_packages(
            jac_config, npm_deps, npm_dev_deps
        );
        needs_reinstall = migrated;

        all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
        (npm_deps, added) = _ensure_dependencies(
            jac_config,
            npm_deps,
            all_runtime,
            is_dev=False,
            description="Core client runtime library."
        );
        needs_reinstall = needs_reinstall or added;

        (npm_dev_deps, added) = _ensure_dependencies(
            jac_config,
            npm_dev_deps,
            CORE_DEV_DEPS,
            is_dev=True,
            description="Build toolchain dependency."
        );
        needs_reinstall = needs_reinstall or added;

        if needs_reinstall {
            _clear_node_modules(self.get_jac_config().get_client_dir());
        }
    }
    merged_npm_deps = {** npm_deps, ** target_scoped_npm_deps};

    user_config: dict[str, any] = {
        'api': client_config.get('api', {}),
        'base_path': client_config.get('base_path', '/'),
        'vite': client_config.get('vite', {}),
        'ts': client_config.get('ts', {}),
        'configs': client_config.get('configs', {}),
        'paths': client_config.get('paths', {}),
        'routing': client_config.get('routing', {}),
        'npm': client_config.get('npm', {}),
        'pwa': client_config.get('pwa', {}),
        'package': {
            'name': jac_config.project.name,
            'version': jac_config.project.version,
            'description': jac_config.project.description,
            'dependencies': merged_npm_deps,
            'devDependencies': npm_dev_deps
        }
    };
    self._config = deep_merge(default_config, user_config);
    return self._config;
}

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

impl JacClientConfig.is_pwa_enabled(self: JacClientConfig) -> bool {
    pwa_config = self.get_pwa_config();

    return len(pwa_config) > 0;
}

impl JacClientConfig.check_runtime_version(
    self: JacClientConfig
) -> tuple[bool, str, str] {
    jac_config = self.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps('npm'));

    user_react: str = str(npm_deps.get('react', ''));
    required_react: str = CORE_RUNTIME_DEPS.get('react', '');

    if not user_react {
        if 'jac-client-node' in npm_deps {
            return (False, 'jac-client-node (legacy)', required_react);
        }
        return (False, '', required_react);
    }

    all_required = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
    missing = [
        name
        for name in all_required
        if name not in npm_deps
    ];
    if missing {
        return (False, user_react, required_react);
    }

    return (True, user_react, required_react);
}

impl JacClientConfig.get_mobile_config(self: JacClientConfig) -> dict[str, any] {
    client_config = self.get_jac_config().get_plugin_config("client");
    section = client_config.get("mobile", {});
    return section if isinstance(section, dict) else {};
}

impl JacClientConfig.get_react_native_config(self: JacClientConfig) -> dict[str, any] {
    client_config = self.get_jac_config().get_plugin_config("client");
    section = client_config.get("react_native", {});
    return section if isinstance(section, dict) else {};
}

impl JacClientConfig.sync_runtime_version(self: JacClientConfig) -> None {
    jac_config = self.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps('npm'));

    npm_plugin_deps: dict = dict(jac_config.plugin_dependencies.get('npm', {}));
    dev_section = npm_plugin_deps.get('dev', {});
    npm_dev_deps: dict = dict(dev_section) if isinstance(dev_section, dict) else {};
    _migrate_legacy_meta_packages(jac_config, npm_deps, npm_dev_deps);

    all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
    for (name, version) in all_runtime.items() {
        jac_config.add_dependency(name, version, dev=False, dep_type='npm');
    }
    for (name, version) in CORE_DEV_DEPS.items() {
        jac_config.add_dependency(name, version, dev=True, dep_type='npm');
    }
    jac_config.save();

    self.invalidate();
    console.success("Synced all core dependencies to latest required versions");
}
