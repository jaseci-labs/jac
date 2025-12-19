"""Get package.json-specific configuration."""

impl JacClientConfig.get_package_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('package', {});
}

"""Get TypeScript-specific configuration."""
impl JacClientConfig.get_ts_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('ts', {});
}

"""Get Vite-specific configuration."""
impl JacClientConfig.get_vite_config(self: JacClientConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('vite', {});
}

"""Deep merge two dictionaries."""
impl JacClientConfig._deep_merge(
    self: JacClientConfig, base: dict[(str, Any)], override_dict: dict[(str, Any)]
) -> dict[str, Any] {
    result = base.copy();
    for (key, value) in override_dict.items() {
        if (
            (key in result)
            and isinstance(result[key], dict)
            and isinstance(value, dict)
        ) {
            result[key] = self._deep_merge(result[key], value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

"""Load configuration from config.json, merging with defaults."""
impl JacClientConfig.load(self: JacClientConfig) -> dict[str, Any] {
    if (self._config is not None) {
        return self._config;
    }
    default_config = self._get_default_config();
    if not self.config_file.exists() {
        self._config = default_config;
        return self._config;
    }
    try {
        with self.config_file.open(encoding='utf-8') as f {
            user_config = json.load(f);
        }
    } except json.JSONDecodeError as e {
        raise ClientBundleError(f"Invalid JSON in {self.config_file}: {e}") from e ;
    } except Exception as e {
        raise ClientBundleError(f"Error reading config file {self.config_file}: {e}") from e ;
    }
    self._config = self._deep_merge(default_config, user_config);
    return self._config;
}

"""Get default configuration structure."""
impl JacClientConfig._get_default_config(self: JacClientConfig) -> dict[str, Any] {
    return {
        'vite': {
            'plugins': [],
            'lib_imports': [],
            'build': {},
            'server': {},
            'resolve': {}
        },
        'ts': {},
        'package': {
            'name': '',
            'version': '1.0.0',
            'description': '',
            'dependencies': {},
            'devDependencies': {}
        }
    };
}

"""Initialize config loader."""
impl JacClientConfig.init(self: JacClientConfig, project_dir: Path) {
    self.project_dir = project_dir;
    self.configs_dir = project_dir / '.jac-client.configs';
    self.config_file = project_dir / 'config.json';
    self._config: (dict[(str, Any)] | None) = None;
}
