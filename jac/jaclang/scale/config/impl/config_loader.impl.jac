impl JacScaleConfig.get_plugin_name(self: JacScaleConfig) -> str {
    return "scale";
}

impl JacScaleConfig.get_config_schema(self: JacScaleConfig) -> dict[str, any] {
    import from jaclang.scale.config.validation { scale_schema_options }
    return {"section": "scale", "options": scale_schema_options()};
}

impl JacScaleConfig.get_config_strict_env(self: JacScaleConfig) -> str {
    import from jaclang.scale.config.validation { STRICT_ENV }
    return STRICT_ENV;
}

impl JacScaleConfig.get_default_config(self: JacScaleConfig) -> dict[str, any] {
    return {
        'sso': {
            'host': 'http://localhost:8000',
            'client_auth_callback_url': '',
            'google': {'client_id': '', 'client_secret': ''},
            'apple': {'client_id': '', 'client_secret': ''},
            'github': {'client_id': '', 'client_secret': ''},
            'firebase': {'project_id': ''}
        },
        'database': {
            'url': None,
            'deploy_mode': 'image',
            'postgres_image': 'postgres:18',
            'postgres_storage': '2Gi'
        },
        'websocket': {
            'backplane': None,
            'max_message_bytes': 65536,
            'max_connections_per_target': 5000,
            'max_connections_per_user': 10,
            'max_anonymous_per_target': 100,
            'target_timeout_seconds': 30,
            'messages_per_second': 20
        },
        'secrets': {},
        'server': {'structured_logs': True},
        'webhook': {
            'secret': 'webhook-secret-key',
            'signature_header': 'X-Webhook-Signature',
            'timestamp_header': 'X-Webhook-Timestamp',
            'verify_signature': True,
            'replay_tolerance_seconds': 300,
            'max_body_bytes': 1048576,
            'rate_limit_per_minute': 0,
            'api_key_expiry_days': 365
        },
        'monitoring': {
            'enabled': False,
            'endpoint': '/metrics',
            'namespace': 'jaclang_scale',
            'walker_metrics': False,
            'histogram_buckets': [
                0.005,
                0.01,
                0.025,
                0.05,
                0.075,
                0.1,
                0.25,
                0.5,
                0.75,
                1.0,
                2.5,
                5.0,
                10.0
            ],
            'prometheus_admin_password': 'Adminpassword123',
            'k8s_metrics_enabled': True
        },
        'admin': {
            'enabled': True,
            'username': 'admin',
            'email': 'admin@localhost',
            'default_password': 'changeme',
            'session_expiry_hours': 24,
            'require_password_reset': True
        },
        'scheduler': {
            'collection': 'scheduled_jobs',
            'thread_pool_size': 10,
            'misfire_grace_time': 60,
            'shutdown_timeout': 10,
            'system_user_password': '__no_login__',
            'user_exists_ttl': 30.0
        },
        'telemetry': {'max_traces': 1000},
        'emailer': {
            'provider': '',
            'enabled': True,
            'from_address': '',
            'smtp': {
                'host': 'localhost',
                'port': 25,
                'username': '',
                'password': '',
                'use_tls': True,
                'timeout': 10.0
            }
        },
        'auth': {
            'reset_token_ttl_seconds': 1800,
            'verify_token_ttl_seconds': 86400,
            'reset_url_template': '',
            'verify_url_template': '',
            'token_collection': 'auth_tokens'
        },
        'gateway': {'gateway_port': 8000, 'gateway_host': '0.0.0.0', 'colocate': True}
    };
}

impl JacScaleConfig.get_sso_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    sso_config = config.get('sso', {});
    google_config = sso_config.get('google', {});
    apple_config = sso_config.get('apple', {});
    github_config = sso_config.get('github', {});
    firebase_config = sso_config.get('firebase', {});
    return {
        'host': sso_config.get('host', 'http://localhost:8000'),
        'client_auth_callback_url': sso_config.get('client_auth_callback_url', ''),
        'google': {
            'client_id': google_config.get('client_id', ''),
            'client_secret': google_config.get('client_secret', '')
        },
        'apple': {
            'client_id': apple_config.get('client_id', ''),
            'client_secret': apple_config.get('client_secret', '')
        },
        'github': {
            'client_id': github_config.get('client_id', ''),
            'client_secret': github_config.get('client_secret', '')
        },
        'firebase': {
            'project_id': resolve_firebase_project_id(
                FIREBASE_AUTH_PROJECT_ID_ENV,
                firebase_config.get('project_id', '') or None
            )
                or ''
        }
    };
}

impl JacScaleConfig.get_deploy_database_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    db_config = config.get('database', {});
    return {
        'url': db_config.get('url'),
        'deploy_mode': db_config.get('deploy_mode', 'image'),
        'postgres_image': db_config.get('postgres_image', 'postgres:18'),
        'postgres_storage': db_config.get('postgres_storage', '2Gi')
    };
}

impl JacScaleConfig.get_database_config(self: JacScaleConfig) -> dict[str, any] {
    resolved = self.get_deploy_database_config();
    resolved['url'] = os.environ.get('JAC_DB_URL') or resolved['url'];
    return resolved;
}


impl JacScaleConfig.get_kubernetes_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    k8s_config = dict(config.get('kubernetes', {}));

    monitoring = self.get_monitoring_config();
    k8s_config['monitoring_enabled'] = monitoring['enabled'];
    k8s_config['k8s_metrics_enabled'] = monitoring['k8s_metrics_enabled'];
    k8s_config['prometheus_admin_password'] = monitoring['prometheus_admin_password'];

    k8s_config['admin_username'] = self.get_admin_config().get('username', 'admin');

    system_deps = self.get_jac_config().get_plugin_deps("system");
    k8s_config['service_dependencies'] = [
        name
        for name in system_deps.keys()
        if name
    ];

    import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        KubernetesConfig,
        k8s_safe_slug
    }
    derived = k8s_safe_slug(self.get_jac_config().project.name, fallback='');
    if derived {
        k8s_config.setdefault('app_name', derived);
    }
    k8s_config_obj = KubernetesConfig.from_dict(KubernetesConfig, k8s_config);
    return k8s_config_obj.to_dict();
}

impl JacScaleConfig.get_server_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    server_config = config.get('server', {});
    return {'structured_logs': bool(server_config.get('structured_logs', True))};
}

impl JacScaleConfig.get_webhook_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    webhook_config = config.get('webhook', {});
    return {
        'signature_header': webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        ),
        'timestamp_header': webhook_config.get(
            'timestamp_header', 'X-Webhook-Timestamp'
        ),
        'verify_signature': webhook_config.get('verify_signature', True),
        'replay_tolerance_seconds': int(
            webhook_config.get('replay_tolerance_seconds', 300)
        ),
        'max_body_bytes': int(webhook_config.get('max_body_bytes', 1048576)),
        'rate_limit_per_minute': int(webhook_config.get('rate_limit_per_minute', 0)),
        'api_key_expiry_days': int(webhook_config.get('api_key_expiry_days', 365))
    };
}

impl JacScaleConfig.get_secrets_config(self: JacScaleConfig) -> dict[str, str] {
    config = self.load();
    return config.get('secrets', {});
}

impl sanitize_prometheus_namespace(name: str) -> str {
    import re;

    sanitized = re.sub(r'[^a-zA-Z0-9]', '_', name);

    sanitized = re.sub(r'_+', '_', sanitized);

    sanitized = sanitized.strip('_');

    if sanitized and sanitized[0].isdigit() {
        sanitized = f"_{sanitized}";
    }
    return sanitized or 'jaclang_scale';
}

impl _resolve_prometheus_namespace(configured: str | None, k8s_namespace: str) -> str {
    configured = "" if configured is None else str(configured);
    if not configured {
        return sanitize_prometheus_namespace(k8s_namespace);
    }
    sanitized = sanitize_prometheus_namespace(configured);
    if sanitized != configured and not _prometheus_namespace_warned {
        _prometheus_namespace_warned = True;
        import logging;
        logging.getLogger(__name__).warning(
            f"jac.toml [scale.monitoring] namespace '{configured}' is not a valid "
            f"Prometheus prefix; metrics are exported under '{sanitized}' instead. "
            "Update dashboards and alert rules that reference the old prefix."
        );
    }
    return sanitized;
}

impl JacScaleConfig.get_monitoring_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    monitoring_config = config.get('monitoring', {});
    default_buckets = [
        0.005,
        0.01,
        0.025,
        0.05,
        0.075,
        0.1,
        0.25,
        0.5,
        0.75,
        1.0,
        2.5,
        5.0,
        10.0
    ];

    k8s_config = config.get('kubernetes', {});
    namespace = _resolve_prometheus_namespace(
        monitoring_config.get('namespace'), k8s_config.get('namespace', 'default')
    );
    return {
        'enabled': monitoring_config.get('enabled', False),
        'endpoint': monitoring_config.get('endpoint', '/metrics'),
        'namespace': namespace,
        'walker_metrics': monitoring_config.get('walker_metrics', False),
        'histogram_buckets': monitoring_config.get(
            'histogram_buckets', default_buckets
        ),
        'k8s_metrics_enabled': monitoring_config.get('k8s_metrics_enabled', True),
        'prometheus_admin_password': monitoring_config.get(
            'prometheus_admin_password', 'Adminpassword123'
        )
    };
}

impl JacScaleConfig.get_events_config(self: JacScaleConfig) -> dict[str, any] {
    import from jaclang.scale.events.broker { RetryPolicy }
    config = self.load();
    events_config = config.get('events', {});
    retry_config = events_config.get('retry', {});
    retry_defaults = RetryPolicy();
    return {
        'enabled': events_config.get('enabled', False),
        'url': events_config.get('url'),
        'consumer_group': events_config.get('consumer_group', 'jac-scale'),
        'serializer': events_config.get('serializer', 'json'),
        'retry': {
            'max_attempts': retry_config.get(
                'max_attempts', retry_defaults.max_attempts
            ),
            'backoff_seconds': retry_config.get(
                'backoff_seconds', retry_defaults.backoff_seconds
            ),
            'dead_letter_suffix': retry_config.get(
                'dead_letter_suffix', retry_defaults.dead_letter_suffix
            )
        }
    };
}

impl _ws_positive(ws_config: dict, key: str, fallback: (int | float)) -> float {
    raw = ws_config.get(key, fallback);
    if isinstance(raw, bool) or not isinstance(raw, (int, float, str)) {
        raise ValueError(f"[scale.websocket].{key} must be a number, got {raw!r}.");
    }
    try {
        value = float(raw);
    } except ValueError {
        raise ValueError(f"[scale.websocket].{key} must be a number, got {raw!r}.");
    }
    if value <= 0 {
        raise ValueError(
            f"[scale.websocket].{key} must be greater than 0, got {raw!r}. "
            "These limits have no 'unlimited' value; set a high one instead."
        );
    }
    return value;
}

impl JacScaleConfig.get_websocket_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    ws_config: dict = config.get('websocket', {});
    backplane = ws_config.get('backplane');
    if backplane is not None {
        backplane = str(backplane).lower();
    }
    return {
        'backplane': backplane,
        'max_message_bytes': int(_ws_positive(ws_config, 'max_message_bytes', 65536)),
        'max_connections_per_target': int(
            _ws_positive(ws_config, 'max_connections_per_target', 5000)
        ),
        'max_connections_per_user': int(
            _ws_positive(ws_config, 'max_connections_per_user', 10)
        ),
        'max_anonymous_per_target': int(
            _ws_positive(ws_config, 'max_anonymous_per_target', 100)
        ),
        'target_timeout_seconds': _ws_positive(ws_config, 'target_timeout_seconds', 30),
        'messages_per_second': _ws_positive(ws_config, 'messages_per_second', 20)
    };
}

impl get_scale_config(project_dir: Path | None = None) -> JacScaleConfig {
    if _scale_config_instance is not None {
        cached_dir = _scale_config_instance.project_dir;
        if (
            project_dir is not None
            and cached_dir is not None
            and Path(project_dir).resolve() != cached_dir.resolve()
        ) {
            raise RuntimeError(
                f"get_scale_config(project_dir={project_dir}) called after the "
                f"config was already loaded for "
                f"{_scale_config_instance.project_dir}. Call "
                "reset_scale_config() first, or pass the config explicitly; "
                "returning the cached instance would silently read the wrong "
                "project's config."
            );
        }
        return _scale_config_instance;
    }
    new_instance = JacScaleConfig(project_dir);
    _scale_config_instance = new_instance;
    return new_instance;
}

impl peek_scale_config -> JacScaleConfig | None {
    return _scale_config_instance;
}

impl reset_scale_config -> None {
    _scale_config_instance = None;
    _prometheus_namespace_warned = False;
    _app_scale_cache.clear();
}

impl JacScaleConfig.get_telemetry_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    telemetry_config = config.get('telemetry', {});
    return {'max_traces': int(telemetry_config.get('max_traces', 1000))};
}

impl JacScaleConfig.get_scheduler_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    scheduler_config = config.get('scheduler', {});
    return {
        'collection': scheduler_config.get('collection', 'scheduled_jobs'),
        'thread_pool_size': int(scheduler_config.get('thread_pool_size', 10)),
        'misfire_grace_time': int(scheduler_config.get('misfire_grace_time', 60)),
        'shutdown_timeout': int(scheduler_config.get('shutdown_timeout', 10)),
        'system_user_password': scheduler_config.get(
            'system_user_password', '__no_login__'
        ),
        'user_exists_ttl': float(scheduler_config.get('user_exists_ttl', 30.0))
    };
}

impl JacScaleConfig.get_emailer_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    emailer_config = config.get('emailer', {}) or {};
    smtp_config = dict(emailer_config.get('smtp', {}) or {});
    smtp_password_env = os.environ.get('EMAILER_SMTP_PASSWORD');
    if smtp_password_env {
        smtp_config['password'] = smtp_password_env;
    }
    return {
        'provider': emailer_config.get('provider', ''),
        'enabled': bool(emailer_config.get('enabled', True)),
        'from_address': emailer_config.get('from_address', ''),
        'smtp': {
            'host': smtp_config.get('host', 'localhost'),
            'port': int(smtp_config.get('port', 25)),
            'username': smtp_config.get('username', ''),
            'password': smtp_config.get('password', ''),
            'use_tls': bool(smtp_config.get('use_tls', True)),
            'timeout': float(smtp_config.get('timeout', 10.0))
        }
    };
}

impl JacScaleConfig.get_auth_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    auth_config = config.get('auth', {}) or {};
    return {
        'reset_token_ttl_seconds': int(
            auth_config.get('reset_token_ttl_seconds', 1800)
        ),
        'verify_token_ttl_seconds': int(
            auth_config.get('verify_token_ttl_seconds', 86400)
        ),
        'reset_url_template': auth_config.get('reset_url_template', ''),
        'verify_url_template': auth_config.get('verify_url_template', ''),
        'token_collection': auth_config.get('token_collection', 'auth_tokens'),
        'forgot_password_rate_per_hour': int(
            auth_config.get('forgot_password_rate_per_hour', 3)
        ),
        'forgot_password_burst': int(auth_config.get('forgot_password_burst', 3)),
        'send_verification_rate_per_hour': int(
            auth_config.get('send_verification_rate_per_hour', 5)
        ),
        'send_verification_burst': int(auth_config.get('send_verification_burst', 5))
    };
}

impl JacScaleConfig.get_gateway_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    return normalize_gateway_config(config.get('gateway', {}));
}

impl JacScaleConfig.get_app_scale_config(
    self: JacScaleConfig, app_name: str
) -> dict[str, any] {
    if not app_name {
        return {};
    }
    cached = _app_scale_cache.get(app_name);
    if cached is not None {
        return dict(cached);
    }
    try {
        resolved = app_scale_overrides(self.get_jac_config(), app_name);
    } except Exception {
        resolved = {};
    }
    _app_scale_cache[app_name] = resolved;
    return dict(resolved);
}


impl _pick_app_scale_keys(section: dict[str, any] | None) -> dict[str, any] {
    import copy;
    if not isinstance(section, dict) {
        return {};
    }
    return {
        key: copy.deepcopy(value)
        for (key, value) in section.items()
        if key in APP_SCALE_KEYS
    };
}


impl app_scale_overrides(config: any, app_name: str) -> dict[str, any] {
    if config is None or not app_name or app_name not in config.apps {
        return {};
    }
    app = config.apps[app_name];
    overlays = app.overlays if isinstance(app.overlays, dict) else {};
    declared = overlays.get("scale");
    if isinstance(declared, dict) {
        import from jaclang.project.config_schema { report_schema_findings }
        import from jaclang.scale.config.validation {
            STRICT_ENV,
            validate_app_scale_config
        }
        report_schema_findings(
            validate_app_scale_config(declared, app_name),
            f"apps.{app_name}.scale",
            STRICT_ENV
        );
    }
    try {
        effective = config.effective_for_app(app_name);
    } except Exception {
        return _pick_app_scale_keys(declared);
    }
    plugins = effective.plugins if isinstance(effective.plugins, dict) else {};
    return _pick_app_scale_keys(plugins.get("scale", {}));
}


impl normalize_gateway_config(gateway_config: dict[str, any] | None) -> dict[str, any] {
    raw = dict(gateway_config or {});
    cors_config = dict(raw.get('cors', {}) or {});
    rl_config = dict(raw.get('rate_limit', {}) or {});
    normalized = {
        'colocate': bool(raw.get('colocate', True)),
        'gateway_port': int(raw.get('gateway_port', 8000)),
        'gateway_host': str(raw.get('gateway_host', '0.0.0.0')),
        'gateway_port_pinned': bool(raw.get('gateway_port_pinned', False)),
        'http_forward_timeout': float(raw.get('http_forward_timeout', 30)),
        'rate_limit': {
            'enabled': bool(rl_config.get('enabled', False)),
            'per_ip_rpm': int(rl_config.get('per_ip_rpm', 60)),
            'per_user_rpm': int(rl_config.get('per_user_rpm', 0)),
            'burst_multiplier': float(rl_config.get('burst_multiplier', 2.0)),
            'exempt_paths': list(
                rl_config.get('exempt_paths', ["/health", "/healthz", "/metrics"])
            ),
            'shared': bool(rl_config.get('shared', True))
        },
        'cors': {
            'allow_origins': list(cors_config.get('allow_origins', ["*"])),
            'allow_methods': list(cors_config.get('allow_methods', ["*"])),
            'allow_headers': list(cors_config.get('allow_headers', ["*"])),
            'allow_credentials': bool(cors_config.get('allow_credentials', False)),
            'expose_headers': list(cors_config.get('expose_headers', [])),
            'max_age': int(cors_config.get('max_age', 600))
        },
        'identity': {
            'gateway_owned': bool(
                dict(raw.get('identity', {}) or {}).get('gateway_owned', True)
            )
        },
        'ingress': dict(raw.get('ingress', {}) or {}),
        'shared_volumes': list(raw.get('shared_volumes', []) or []),
        'logs': dict(raw.get('logs', {}) or {}),
        'tracing': dict(raw.get('tracing', {}) or {})
    };
    for boot_key in GATEWAY_BOOT_KEYS {
        if boot_key in raw and raw[boot_key] is not None {
            normalized[boot_key] = raw[boot_key];
        }
    }
    for pod_key in GATEWAY_POD_KEYS {
        if pod_key in raw and raw[pod_key] is not None {
            normalized[pod_key] = raw[pod_key];
        }
    }
    return normalized;
}

impl JacScaleConfig.get_admin_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    admin_config = config.get('admin', {});
    return {
        'enabled': admin_config.get('enabled', True),
        'username': admin_config.get('username', 'admin'),
        'email': admin_config.get('email', 'admin@localhost'),
        'default_password': admin_config.get('default_password', 'changeme'),
        'session_expiry_hours': int(admin_config.get('session_expiry_hours', 24)),
        'require_password_reset': admin_config.get('require_password_reset', True)
    };
}
