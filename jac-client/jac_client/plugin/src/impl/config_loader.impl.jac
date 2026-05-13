"""Implementation of Jac Client configuration loader.

This module provides the implementation for JacClientConfig, which inherits
from PluginConfigBase for common configuration loading functionality.

The base class handles: init, get_jac_config, get_section.
This file implements plugin-specific methods including a custom load()
that combines plugin config with npm dependencies.
"""
import shutil;
import from jaclang.cli.console { console }
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.plugin_config { deep_merge }

# Core dependency versions — individual packages instead of meta-packages.
# These are the required versions for runtime compatibility.

# Runtime dependencies (always injected)
glob CORE_RUNTIME_DEPS: dict[str, str] = {
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0"
     },
     # Optional runtime dependencies (injected by default, separable later)
     OPTIONAL_RUNTIME_DEPS: dict[str, str] = {
         "react-hook-form": "^7.71.0",
         "zod": "^4.3.6",
         "@hookform/resolvers": "^5.2.2"
     },
     # Dev/build dependencies (always injected)
     CORE_DEV_DEPS: dict[str, str] = {
         "vite": "^6.4.1",
         "@vitejs/plugin-react": "^4.2.1",
         "typescript": "^5.3.3",
         "@types/react": "^18.2.0",
         "@types/react-dom": "^18.2.0"
     },
     # Legacy meta-package names (for migration)
     LEGACY_META_PACKAGES = {"jac-client-node","@jac-client/dev-deps"};

# ============================================================================
# DEPENDENCY MANAGEMENT HELPERS
# ============================================================================
"""Ensure a set of dependencies exist in jac.toml, adding any that are missing.

Returns updated deps dict and whether node_modules should be cleared.
"""
def _ensure_dependencies(
    jac_config: Any,
    deps: dict,
    required: dict[str, str],
    is_dev: bool,
    description: str
) -> tuple[dict, bool] {
    needs_reinstall = False;
    for (name, version) in required.items() {
        if name not in deps {
            console.print(
                f"\n  [yellow]⚠[/yellow] Missing required {'dev '
                    if is_dev
                    else ''}dependency: [bold]{name}[/bold]"
            );
            console.print(f"  [dim]{description}[/dim]");
            jac_config.add_dependency(name, version, dev=is_dev, dep_type='npm');
            deps = {name: version, ** deps};
            console.print(f"  [green]✔[/green] Added {name}@{version} to jac.toml");
            needs_reinstall = True;
        }
    }
    if needs_reinstall {
        jac_config.save();
    }
    return (deps, needs_reinstall);
}

"""Migrate away from legacy meta-packages (jac-client-node, @jac-client/dev-deps).

Removes the meta-package entry and injects the individual deps it contained.
Returns updated deps dict and whether migration occurred.
"""
def _migrate_legacy_meta_packages(
    jac_config: Any, npm_deps: dict, npm_dev_deps: dict
) -> tuple[dict, dict, bool] {
    migrated = False;

    if 'jac-client-node' in npm_deps {
        console.print(
            "\n  [yellow]⚠[/yellow] Migrating from [bold]jac-client-node[/bold] "
            "meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('jac-client-node', dev=False, dep_type='npm');
        del npm_deps['jac-client-node'];
        # Inject individual runtime deps (core + optional)
        all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
        for (name, version) in all_runtime.items() {
            if name not in npm_deps {
                jac_config.add_dependency(name, version, dev=False, dep_type='npm');
                npm_deps[name] = version;
            }
        }
        console.print(
            "  [green]✔[/green] Replaced jac-client-node with individual packages"
        );
        migrated = True;
    }

    if '@jac-client/dev-deps' in npm_dev_deps {
        console.print(
            "\n  [yellow]⚠[/yellow] Migrating from [bold]@jac-client/dev-deps[/bold] "
            "meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('@jac-client/dev-deps', dev=True, dep_type='npm');
        del npm_dev_deps['@jac-client/dev-deps'];
        for (name, version) in CORE_DEV_DEPS.items() {
            if name not in npm_dev_deps {
                jac_config.add_dependency(name, version, dev=True, dep_type='npm');
                npm_dev_deps[name] = version;
            }
        }
        console.print(
            "  [green]✔[/green] Replaced @jac-client/dev-deps with individual packages"
        );
        migrated = True;
    }

    if migrated {
        jac_config.save();
    }
    return (npm_deps, npm_dev_deps, migrated);
}

"""Clear node_modules to force dependency reinstall."""
def _clear_node_modules(project_dir: Path | None) {
    if project_dir is not None {
        node_modules: Path = project_dir / '.jac' / 'client' / 'node_modules';
        if node_modules.exists() {
            shutil.rmtree(node_modules);
            console.print(f"  [dim]Reinstalling dependencies...[/dim]\n");
        }
    }
}

"""Get the plugin section name for client."""
impl JacClientConfig.get_plugin_name(self: JacClientConfig) -> str {
    return "client";
}

"""Get default configuration structure for client."""
impl JacClientConfig.get_default_config(self: JacClientConfig) -> dict[str, Any] {
    return {
        'api': {'base_url': ''},
        'vite': {
            'plugins': [],
            'lib_imports': [],
            'define': {},  # Custom define values (env vars, constants)
            'build': {},
            'server': {},
            'resolve': {}
        },
        'ts': {'compilerOptions': {}, 'include': [], 'exclude': []},
        'configs': {},  # Generic config file generation: { "postcss": {...}, "tailwind": {...} }
        'paths': {},  # Import path aliases: { "@components/*": "./components/*" }
        'npm': {},  # NPM registry config: { "scoped_registries": {...}, "auth": {...} }
        'package': {
            'name': '',
            'version': '1.0.0',
            'description': '',
            'dependencies': {},
            'devDependencies': {}
        }
    };
}

"""Load configuration from jac.toml, merging with defaults.

Overrides base class to also include npm dependencies from [dependencies.npm].
Ensures core dependencies are present in jac.toml, migrating legacy meta-packages if needed.
"""
impl JacClientConfig.load(self: JacClientConfig) -> dict[str, Any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    jac_config = self.get_jac_config();
    # Get client plugin config from [plugins.client]
    client_config = jac_config.get_plugin_config('client');
    # Get npm dependencies from [dependencies.npm]
    npm_deps = jac_config.get_plugin_deps('npm');
    # Get npm dev dependencies from [dev-dependencies.npm]
    # These are stored in plugin_dependencies["npm"]["dev"] after parsing
    npm_plugin_deps: dict = dict(jac_config.plugin_dependencies.get('npm', {}));
    dev_section = npm_plugin_deps.get('dev', {});
    npm_dev_deps: dict = dict(dev_section) if isinstance(dev_section, dict) else {};

    # Migrate legacy meta-packages if present
    (npm_deps, npm_dev_deps, migrated) = _migrate_legacy_meta_packages(
        jac_config, npm_deps, npm_dev_deps
    );
    needs_reinstall = migrated;

    # Ensure core runtime dependencies are present
    all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
    (npm_deps, added) = _ensure_dependencies(
        jac_config,
        npm_deps,
        all_runtime,
        is_dev=False,
        description="Core client runtime library."
    );
    needs_reinstall = needs_reinstall or added;

    # Ensure core dev/build dependencies are present
    (npm_dev_deps, added) = _ensure_dependencies(
        jac_config,
        npm_dev_deps,
        CORE_DEV_DEPS,
        is_dev=True,
        description="Build toolchain dependency."
    );
    needs_reinstall = needs_reinstall or added;

    # Clear node_modules if any dependency was added or migrated
    if needs_reinstall {
        _clear_node_modules(self.project_dir);
    }

    # Build user config in the expected internal format
    user_config: dict[str, Any] = {
        'api': client_config.get('api', {}),
        'vite': client_config.get('vite', {}),
        'ts': client_config.get('ts', {}),
        'configs': client_config.get('configs', {}),
        'paths': client_config.get('paths', {}),
        'npm': client_config.get('npm', {}),
        'pwa': client_config.get('pwa', {}),
        'package': {
            'name': jac_config.project.name,
            'version': jac_config.project.version,
            'description': jac_config.project.description,
            'dependencies': npm_deps,
            'devDependencies': npm_dev_deps
        }
    };
    self._config = deep_merge(default_config, user_config);
    return self._config;
}

"""Get package configuration (npm dependencies)."""
impl JacClientConfig.get_package_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('package', {});
}

"""Get API configuration (base_url for backend)."""
impl JacClientConfig.get_api_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('api', {});
}

"""Get Vite-specific configuration."""
impl JacClientConfig.get_vite_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('vite', {});
}

"""Get TypeScript-specific configuration for tsconfig.json customization."""
impl JacClientConfig.get_ts_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('ts', {});
}

"""Get generic config files to generate (postcss, tailwind, etc.)."""
impl JacClientConfig.get_configs(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('configs', {});
}

"""Get npm registry configuration for .npmrc generation."""
impl JacClientConfig.get_npm_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('npm', {});
}

"""Save configuration back to jac.toml using core JacConfig."""
impl JacClientConfig.save(self: JacClientConfig) -> None {
    jac_config = self.get_jac_config();
    jac_config.save();
}

"""Add an npm dependency."""
impl JacClientConfig.add_dependency(
    self: JacClientConfig, name: str, version: str, is_dev: bool = False
) -> None {
    jac_config = self.get_jac_config();
    jac_config.add_dependency(name, version, dev=is_dev, dep_type="npm");
    # Invalidate cache
    self.invalidate();
}

"""Remove an npm dependency."""
impl JacClientConfig.remove_dependency(
    self: JacClientConfig, name: str, is_dev: bool = False
) -> bool {
    jac_config = self.get_jac_config();
    result = jac_config.remove_dependency(name, dev=is_dev, dep_type="npm");
    # Invalidate cache
    self.invalidate();
    return result;
}

"""Get import path aliases from [plugins.client.paths] in jac.toml."""
impl JacClientConfig.get_paths_config(self: JacClientConfig) -> dict[str, str] {
    config = self.load();
    return config.get('paths', {});
}

"""Get PWA configuration from [plugins.client.pwa] in jac.toml."""
impl JacClientConfig.get_pwa_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('pwa', {});
}

"""Check if PWA is enabled (pwa section exists in jac.toml)."""
impl JacClientConfig.is_pwa_enabled(self: JacClientConfig) -> bool {
    pwa_config = self.get_pwa_config();
    # PWA is enabled if the section exists (even if empty)
    # The section is added by `jac setup pwa`
    return len(pwa_config) > 0;
}

"""Check if core runtime dependencies are present and version-compatible.

Returns tuple of (is_compatible, user_version_summary, required_version_summary).
Checks that all core runtime deps (react, react-dom, etc.) are present.
"""
impl JacClientConfig.check_runtime_version(
    self: JacClientConfig
) -> tuple[bool, str, str] {
    jac_config = self.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps('npm'));

    # Check if react is present as the primary indicator
    user_react: str = str(npm_deps.get('react', ''));
    required_react: str = CORE_RUNTIME_DEPS.get('react', '');

    if not user_react {
        # Legacy check: maybe still using jac-client-node
        if 'jac-client-node' in npm_deps {
            return (False, 'jac-client-node (legacy)', required_react);
        }
        return (False, '', required_react);
    }

    # Check all core deps are present
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

"""Sync core runtime dependency versions in jac.toml."""
impl JacClientConfig.sync_runtime_version(self: JacClientConfig) -> None {
    jac_config = self.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps('npm'));

    # Migrate legacy meta-packages first
    npm_plugin_deps: dict = dict(jac_config.plugin_dependencies.get('npm', {}));
    dev_section = npm_plugin_deps.get('dev', {});
    npm_dev_deps: dict = dict(dev_section) if isinstance(dev_section, dict) else {};
    _migrate_legacy_meta_packages(jac_config, npm_deps, npm_dev_deps);

    # Update all core runtime deps
    all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
    for (name, version) in all_runtime.items() {
        jac_config.add_dependency(name, version, dev=False, dep_type='npm');
    }
    for (name, version) in CORE_DEV_DEPS.items() {
        jac_config.add_dependency(name, version, dev=True, dep_type='npm');
    }
    jac_config.save();
    # Invalidate cache to reload
    self.invalidate();
    console.print(
        "  [green]✔[/green] Synced all core dependencies to latest required versions"
    );
}
