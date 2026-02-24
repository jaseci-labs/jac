"""Implementation of Jac Client configuration loader.

This module provides the implementation for JacClientConfig, which inherits
from PluginConfigBase for common configuration loading functionality.

The base class handles: init, get_jac_config, get_section.
This file implements plugin-specific methods including a custom load()
that combines plugin config with npm dependencies.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.plugin_config { deep_merge }

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
    npm_plugin_deps = jac_config.plugin_dependencies.get('npm', {});
    npm_dev_deps = npm_plugin_deps.get('dev', {})
    if isinstance(npm_plugin_deps.get('dev'), dict)
    else {};
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
