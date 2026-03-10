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

# Core dependency versions - must match jac-client plugin version.
# These are the required versions for runtime compatibility.
glob JAC_CLIENT_NODE_VERSION = "1.0.7",
     JAC_CLIENT_DEV_DEPS_VERSION = "2.0.0";

# ============================================================================
# DEPENDENCY MANAGEMENT HELPERS
# ============================================================================
"""Ensure a core dependency exists in jac.toml, add if missing.

Returns updated deps dict and whether node_modules should be cleared.
"""
def _ensure_dependency(
    jac_config: Any,
    deps: dict,
    name: str,
    version: str,
    is_dev: bool,
    description: str
) -> tuple[dict, bool] {
    if name not in deps {
        console.print(
            f"\n  [yellow]⚠[/yellow] Missing required {'dev '
                if is_dev
                else ''}dependency: [bold]{name}[/bold]"
        );
        console.print(f"  [dim]{description}[/dim]");
        jac_config.add_dependency(name, version, dev=is_dev, dep_type='npm');
        jac_config.save();
        deps = {name: version, ** deps};
        console.print(f"  [green]✔[/green] Added {name}@{version} to jac.toml");
        return (deps, True);  # needs reinstall

    }
    return (deps, False);
}

"""Check and auto-update dependency version if mismatched.

Returns True if version was updated (needs reinstall).
"""
def _check_dependency_version(
    jac_config: Any, deps: dict, name: str, required_version: str, is_dev: bool
) -> bool {
    user_version: str = str(deps.get(name, ''));
    if user_version and user_version != required_version {
        console.print(
            f"\n  [yellow]⚠[/yellow] Version mismatch: {name}@{user_version} "
            f"(required: {required_version})"
        );
        jac_config.add_dependency(name, required_version, dev=is_dev, dep_type='npm');
        jac_config.save();
        console.print(f"  [green]✔[/green] Updated to {name}@{required_version}");
        return True;
    }
    return False;
}

"""Clear node_modules to force dependency reinstall."""
def _clear_node_modules(project_dir: Path | None) -> None {
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
Ensures jac-client-node is present in jac.toml with compatible version.
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

    # Ensure core dependencies are present in jac.toml
    needs_reinstall = False;

    # Runtime dependency: jac-client-node
    (npm_deps, added) = _ensure_dependency(
        jac_config,
        npm_deps,
        name='jac-client-node',
        version=JAC_CLIENT_NODE_VERSION,
        is_dev=False,
        description="This package provides React and other client runtime libraries."
    );
    needs_reinstall = needs_reinstall or added;
    if not added {
        updated = _check_dependency_version(
            jac_config,
            npm_deps,
            'jac-client-node',
            JAC_CLIENT_NODE_VERSION,
            is_dev=False
        );
        needs_reinstall = needs_reinstall or updated;
    }

    # Dev dependency: @jac-client/dev-deps
    (npm_dev_deps, added) = _ensure_dependency(
        jac_config,
        npm_dev_deps,
        name='@jac-client/dev-deps',
        version=JAC_CLIENT_DEV_DEPS_VERSION,
        is_dev=True,
        description="This package provides Vite, TypeScript and build tools."
    );
    needs_reinstall = needs_reinstall or added;
    if not added {
        updated = _check_dependency_version(
            jac_config,
            npm_dev_deps,
            '@jac-client/dev-deps',
            JAC_CLIENT_DEV_DEPS_VERSION,
            is_dev=True
        );
        needs_reinstall = needs_reinstall or updated;
    }

    # Clear node_modules if any dependency was added
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

"""Check if jac-client-node version matches exactly with jac-client plugin.

Returns tuple of (is_compatible, user_version, required_version).
Requires exact version match - even patch versions must match.
"""
impl JacClientConfig.check_runtime_version(
    self: JacClientConfig
) -> tuple[bool, str, str] {
    jac_config = self.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps('npm'));
    user_version: str = str(npm_deps.get('jac-client-node', ''));
    required_version: str = JAC_CLIENT_NODE_VERSION;

    if not user_version {
        return (False, '', required_version);
    }

    # Exact version match required - strip any semver prefixes for comparison
    clean_user: str = user_version.lstrip('^~>=<');
    clean_required: str = required_version.lstrip('^~>=<');

    is_compatible = clean_user == clean_required;
    return (is_compatible, user_version, required_version);
}

"""Sync jac-client-node version in jac.toml to match jac-client plugin."""
impl JacClientConfig.sync_runtime_version(self: JacClientConfig) -> None {
    jac_config = self.get_jac_config();
    # Update the dependency in jac.toml
    jac_config.add_dependency(
        'jac-client-node', JAC_CLIENT_NODE_VERSION, dev=False, dep_type='npm'
    );
    jac_config.save();
    # Invalidate cache to reload
    self.invalidate();
    console.print(
        f"  [green]✔[/green] Synced jac-client-node to {JAC_CLIENT_NODE_VERSION}"
    );
}
