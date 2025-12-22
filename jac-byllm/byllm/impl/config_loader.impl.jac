"""Implementation of jac-byllm configuration loader.

This delegates to the core JacConfig for all configuration operations,
reading from [plugins.byllm] for model, call_params, and litellm config.

Configuration is loaded purely from jac.toml - no environment variable fallbacks.
"""
import from jaclang.project.config { JacConfig }
import from pathlib { Path }
import from typing { Any }

"""Initialize config loader with project directory."""
impl JacByllmConfig.init(self: JacByllmConfig, project_dir: (Path | None) = None) {
    if project_dir is None {
        # Try to find project root from current working directory
        self.project_dir = Path.cwd();
    } else {
        self.project_dir = project_dir;
    }
    self.config_file = self.project_dir / 'jac.toml';
    self._config: (dict[(str, Any)] | None) = None;
    self._jac_config: (JacConfig | None) = None;
}

"""Get or load the core JacConfig."""
def _get_jac_config(self: JacByllmConfig) -> JacConfig {
    if self._jac_config is None {
        if self.config_file.exists() {
            self._jac_config = JacConfig.load(self.config_file);
        } else {
            # Create a new config with project root
            self._jac_config = JacConfig();
            self._jac_config.toml_path = self.config_file;
            self._jac_config.project_root = self.project_dir;
        }
    }
    return self._jac_config;
}

"""Get model configuration from jac.toml."""
impl JacByllmConfig.get_model_config(self: JacByllmConfig) -> dict[str, Any] {
    config = self.load();
    model_config = config.get('model', {});
    return {
        'default_model': model_config.get('default_model', 'gpt-4o-mini'),
        'api_key': model_config.get('api_key', ''),
        'base_url': model_config.get('base_url', ''),
        'proxy': bool(model_config.get('proxy', False)),
        'verbose': bool(model_config.get('verbose', False))
    };
}

"""Get default call parameters configuration from jac.toml."""
impl JacByllmConfig.get_call_params_config(self: JacByllmConfig) -> dict[str, Any] {
    config = self.load();
    call_params = config.get('call_params', {});
    temperature = call_params.get('temperature', 0.7);
    max_tokens = call_params.get('max_tokens', 0);
    result: dict[str, Any] = {'temperature': temperature};
    # Only include max_tokens if it's set (non-zero)
    if max_tokens > 0 {
        result['max_tokens'] = max_tokens;
    }
    return result;
}

"""Get LiteLLM-specific configuration from jac.toml."""
impl JacByllmConfig.get_litellm_config(self: JacByllmConfig) -> dict[str, Any] {
    config = self.load();
    litellm_config = config.get('litellm', {});
    return {
        'local_cost_map': bool(litellm_config.get('local_cost_map', True)),
        'drop_params': bool(litellm_config.get('drop_params', True))
    };
}

"""Deep merge two dictionaries."""
impl JacByllmConfig._deep_merge(
    self: JacByllmConfig, base: dict[(str, Any)], override_dict: dict[(str, Any)]
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

"""Load configuration from jac.toml, merging with defaults."""
impl JacByllmConfig.load(self: JacByllmConfig) -> dict[str, Any] {
    if (self._config is not None) {
        return self._config;
    }
    default_config = self._get_default_config();
    jac_config = _get_jac_config(self);
    # Get byllm plugin config from [plugins.byllm]
    byllm_config = jac_config.get_plugin_config('byllm');
    # Build user config in the expected internal format
    user_config: dict[str, Any] = {
        'model': byllm_config.get('model', {}),
        'call_params': byllm_config.get('call_params', {}),
        'litellm': byllm_config.get('litellm', {})
    };
    self._config = self._deep_merge(default_config, user_config);
    return self._config;
}

"""Get default configuration structure."""
impl JacByllmConfig._get_default_config(self: JacByllmConfig) -> dict[str, Any] {
    return {
        'model': {
            'default_model': 'gpt-4o-mini',
            'api_key': '',
            'base_url': '',
            'proxy': False,
            'verbose': False
        },
        'call_params': {'temperature': 0.7, 'max_tokens': 0},
        'litellm': {'local_cost_map': True, 'drop_params': True}
    };
}

"""Get or create the global JacByllmConfig instance."""
impl get_byllm_config(project_dir: (Path | None) = None) -> JacByllmConfig {
    global _byllm_config_instance;
    if _byllm_config_instance is None {
        _byllm_config_instance = JacByllmConfig(project_dir);
    }
    return _byllm_config_instance;
}

"""Reset the global config instance (useful for testing)."""
impl reset_byllm_config()  -> None {
    global _byllm_config_instance;
    _byllm_config_instance = None;
}
