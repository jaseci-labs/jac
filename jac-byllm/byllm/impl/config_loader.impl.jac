"""Implementation of jac-byllm configuration loader.

This module provides the implementation for JacByllmConfig, which inherits
from PluginConfigBase for common configuration loading functionality.

The base class handles: init, load, get_jac_config, deep_merge, get_section.
This file only implements plugin-specific methods.
"""
import from pathlib { Path }
import from typing { Any }

"""Get the plugin section name for byllm."""
impl JacByllmConfig.get_plugin_name(self: JacByllmConfig) -> str {
    return "byllm";
}

"""Get default configuration structure for byllm."""
impl JacByllmConfig.get_default_config(self: JacByllmConfig) -> dict[str, Any] {
    return {
        'model': {
            'default_model': 'gpt-4o-mini',
            'api_key': '',
            'base_url': '',
            'proxy': False,
            'verbose': False
        },
        'call_params': {'temperature': 0.7, 'max_tokens': 0},
        'litellm': {'local_cost_map': True, 'drop_params': True},
        'system_prompt': ''
    };
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

"""Get or create the global JacByllmConfig instance."""
impl get_byllm_config(project_dir: Path | None = None) -> JacByllmConfig {
    global _byllm_config_instance;
    # If project_dir is provided and differs from cached instance, recreate
    if (
        _byllm_config_instance is not None
        and project_dir is not None
        and _byllm_config_instance.project_dir != project_dir
    ) {
        _byllm_config_instance = None;
    }
    if _byllm_config_instance is None {
        _byllm_config_instance = JacByllmConfig(project_dir);
    }
    return _byllm_config_instance;
}

"""Get system prompt from jac.toml configuration."""
impl JacByllmConfig.get_system_prompt(self: JacByllmConfig) -> str {
    config = self.load();
    return config.get('system_prompt', '');
}

"""Reset the global config instance (useful for testing)."""
impl reset_byllm_config -> None {
    global _byllm_config_instance;
    _byllm_config_instance = None;
}
