import from pathlib { Path }

impl JacByllmConfig.get_plugin_name(self: JacByllmConfig) -> str {
    return "byllm";
}

impl JacByllmConfig.get_default_config(self: JacByllmConfig) -> dict[str, any] {
    return {
        'model': {
            'default_model': 'gpt-4o-mini',
            'api_key': '',
            'base_url': '',
            'proxy': False,
            'verbose': False
        },
        'call_params': {'temperature': 0.7, 'max_tokens': 0, 'max_output_retries': 3},
        'litellm': {'local_cost_map': True, 'drop_params': True, 'debug': False},
        'fallback': {'strategy': 'fallback', 'num_retries': 1, 'timeout': 60.0},
        'prompt_caching': {'enabled': True},
        'parallel': {'enabled': False},
        'streaming': {
            'read_timeout': 90.0,
            'connect_timeout': 30.0,
            'write_timeout': 30.0,
            'pool_timeout': 30.0,
            'num_retries': 2,
            'retry_backoff': 1.0
        },
        'system_prompt': '',
        'compaction': {
            'enabled': True,
            'threshold_ratio': 0.80,
            'keep_recent_iterations': 3,
            'ctx_window': 0,
            'compaction_model': ''
        },
        'local': {
            'default_alias': 'gemma-4-e4b',
            'n_ctx': 0,
            'n_gpu_layers': 0,
            'n_threads': 0,
            'verbose': False,
            'auto_download': False
        }
    };
}

impl JacByllmConfig.get_model_config(self: JacByllmConfig) -> dict[str, any] {
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

impl JacByllmConfig.get_call_params_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    call_params = config.get('call_params', {});
    temperature = call_params.get('temperature', 0.7);
    max_tokens = call_params.get('max_tokens', 0);
    result: dict[str, any] = {
        'temperature': temperature,
        'max_output_retries': int(call_params.get('max_output_retries', 3))
    };

    if max_tokens > 0 {
        result['max_tokens'] = max_tokens;
    }
    return result;
}

impl JacByllmConfig.get_litellm_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    litellm_config = config.get('litellm', {});
    return {
        'local_cost_map': bool(litellm_config.get('local_cost_map', True)),
        'drop_params': bool(litellm_config.get('drop_params', True)),
        'debug': bool(litellm_config.get('debug', False))
    };
}

impl JacByllmConfig.get_fallback_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    fallback_config = config.get('fallback', {});
    return {
        'strategy': fallback_config.get('strategy', 'fallback'),
        'num_retries': int(fallback_config.get('num_retries', 1)),
        'timeout': float(fallback_config.get('timeout', 60.0))
    };
}

impl JacByllmConfig.get_prompt_caching_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    pc_config = config.get('prompt_caching', {});
    return {'enabled': bool(pc_config.get('enabled', True))};
}

impl get_byllm_config(project_dir: Path | None = None) -> JacByllmConfig {
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

impl JacByllmConfig.get_parallel_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    parallel_config = config.get('parallel', {});

    import os;
    env_enabled = os.environ.get('BYLLM_PARALLEL_TOOL_CALLING', '').lower() in (
        'true',
        '1',
        'yes'
    );
    toml_enabled = bool(parallel_config.get('enabled', False));
    return {'enabled': env_enabled or toml_enabled};
}

impl JacByllmConfig.get_streaming_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    s = config.get('streaming', {});
    return {
        'read_timeout': float(s.get('read_timeout', 90.0)),
        'connect_timeout': float(s.get('connect_timeout', 30.0)),
        'write_timeout': float(s.get('write_timeout', 30.0)),
        'pool_timeout': float(s.get('pool_timeout', 30.0)),
        'num_retries': max(0, int(s.get('num_retries', 2))),
        'retry_backoff': float(s.get('retry_backoff', 1.0))
    };
}

impl JacByllmConfig.get_system_prompt(self: JacByllmConfig) -> str {
    config = self.load();
    return config.get('system_prompt', '');
}

impl JacByllmConfig.get_compaction_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    c = config.get('compaction', {});
    return {
        'enabled': bool(c.get('enabled', True)),
        'threshold_ratio': float(c.get('threshold_ratio', 0.80)),
        'keep_recent_iterations': int(c.get('keep_recent_iterations', 3)),
        'ctx_window': int(c.get('ctx_window', 0)),
        'compaction_model': str(c.get('compaction_model', ''))
    };
}

impl JacByllmConfig.get_local_config(self: JacByllmConfig) -> dict[str, any] {
    config = self.load();
    local_cfg = config.get('local', {});
    return {
        'default_alias': str(local_cfg.get('default_alias', 'gemma-4-e4b')),
        'n_ctx': int(local_cfg.get('n_ctx', 0)),
        'n_gpu_layers': int(local_cfg.get('n_gpu_layers', 0)),
        'n_threads': int(local_cfg.get('n_threads', 0)),
        'verbose': bool(local_cfg.get('verbose', False)),
        'auto_download': bool(local_cfg.get('auto_download', False))
    };
}

impl reset_byllm_config -> None {
    _byllm_config_instance = None;
}
