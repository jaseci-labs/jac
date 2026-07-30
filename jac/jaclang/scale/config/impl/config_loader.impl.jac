impl JacScaleConfig.get_plugin_name(self: JacScaleConfig) -> str {
    return "scale";
}

impl JacScaleConfig.get_default_config(self: JacScaleConfig) -> dict[str, any] {
    return {
        'jwt': {
            'secret': 'supersecretkey_for_testing_only!',
            'algorithm': 'HS256',
            'exp_delta_days': 7
        },
        'sso': {
            'host': 'http://localhost:8000',
            'client_auth_callback_url': '',
            'google': {'client_id': '', 'client_secret': ''},
            'apple': {'client_id': '', 'client_secret': ''},
            'github': {'client_id': '', 'client_secret': ''},
            'firebase': {'project_id': ''}
        },
        'database': {
            'type': None,
            'mongodb_uri': None,
            'redis_url': None,
            'project_id': None,
            'shelf_db_path': '.jac/data/anchor_store.db',
            'redis_max_memory': '200mb',
            'redis_eviction_policy': 'allkeys-lru',
            'redis_eviction_samples': 5,
            'redis_default_ttl': 3600,
            'redis_max_connections': 20,
            'redis_enable_keyspace_notifications': False,
            'redis_l1_invalidation_enabled': True,
            'redis_l1_invalidation_channel': 'jac:anchor:invalidate',
            'redis_cpu_request': '100m',
            'redis_cpu_limit': '500m',
            'redis_memory_request': '128Mi',
            'redis_memory_limit': '1Gi'
        },
        'websocket': {
            'backplane': None,
            'redis_url': None,
            'max_message_bytes': 65536,
            'max_connections_per_target': 5000,
            'max_connections_per_user': 10,
            'max_anonymous_per_target': 100,
            'target_timeout_seconds': 30,
            'messages_per_second': 20
        },
        'kubernetes': {
            'namespace': 'default',
            'container_port': 8000,
            'mongodb_enabled': True,
            'redis_enabled': True,
            'redis_dashboard': False,
            'mongodb_dashboard': False,
            'mongo_express_username': 'admin',
            'mongo_express_password': 'admin',
            'redis_insight_username': 'admin',
            'redis_insight_password': 'admin',
            'mongodb_root_username': 'admin',
            'mongodb_root_password': 'password',
            'redis_username': 'admin',
            'redis_password': 'password',
            'ingress_node_port': 30080,
            'ingress_limit_rps': 20,
            'ingress_limit_burst_multiplier': 5,
            'ingress_limit_connections': 20,
            'ingress_session_affinity': True,
            'cpu_request': None,
            'cpu_limit': None,
            'memory_request': None,
            'memory_limit': None,
            'readiness_initial_delay': 10,
            'readiness_period': 20,
            'liveness_initial_delay': 10,
            'liveness_period': 20,
            'liveness_failure_threshold': 80
        },
        'secrets': {},
        'server': {
            'port': 8000,
            'host': '0.0.0.0',
            'docs_enabled': True,
            'suppress_health_check_logs': False
        },
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
            'type': 'managed',
            'issuer': '',
            'jwks_url': '',
            'audience': '',
            'reset_token_ttl_seconds': 1800,
            'verify_token_ttl_seconds': 86400,
            'reset_url_template': '',
            'verify_url_template': '',
            'token_collection': 'auth_tokens',
            'password_hash_rounds': 12
        },
        'microservices': {
            'gateway_port': 8000,
            'gateway_host': '0.0.0.0',
            'routes': {},
            'client': {'entry': '', 'dist_dir': '.jac/client/dist', 'base_route': '/'}
        }
    };
}

impl JacScaleConfig.get_jwt_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    jwt_config = config.get('jwt', {});
    return {
        'secret': jwt_config.get('secret', 'supersecretkey_for_testing_only!'),
        'algorithm': jwt_config.get('algorithm', 'HS256'),
        'exp_delta_days': int(jwt_config.get('exp_delta_days', 7))
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

impl JacScaleConfig.get_database_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    db_config = config.get('database', {});
    return {
        'type': db_config.get('type'),
        'mongodb_uri': os.environ.get('MONGODB_URI') or db_config.get('mongodb_uri'),
        'redis_url': os.environ.get('REDIS_URL') or db_config.get('redis_url'),
        'project_id': resolve_firebase_project_id(
            FIRESTORE_PROJECT_ID_ENV, db_config.get('project_id')
        ),
        'shelf_db_path': db_config.get('shelf_db_path', '.jac/data/anchor_store.db'),
        'redis_max_memory': db_config.get('redis_max_memory', '200mb'),
        'redis_eviction_policy': db_config.get('redis_eviction_policy', 'allkeys-lru'),
        'redis_eviction_samples': int(db_config.get('redis_eviction_samples', 5)),
        'redis_default_ttl': int(db_config.get('redis_default_ttl', 3600)),
        'redis_max_connections': int(db_config.get('redis_max_connections', 20)),
        'redis_enable_keyspace_notifications': db_config.get(
            'redis_enable_keyspace_notifications', False
        ),
        'redis_l1_invalidation_enabled': db_config.get(
            'redis_l1_invalidation_enabled', True
        ),
        'redis_l1_invalidation_channel': db_config.get(
            'redis_l1_invalidation_channel', 'jac:anchor:invalidate'
        ),
        'redis_cpu_request': db_config.get('redis_cpu_request', '100m'),
        'redis_cpu_limit': db_config.get('redis_cpu_limit', '500m'),
        'redis_memory_request': db_config.get('redis_memory_request', '128Mi'),
        'redis_memory_limit': db_config.get('redis_memory_limit', '1Gi')
    };
}

impl JacScaleConfig.get_kubernetes_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    k8s_config = config.get('kubernetes', {});

    monitoring = self.get_monitoring_config();
    k8s_config['monitoring_enabled'] = monitoring['enabled'];
    k8s_config['k8s_metrics_enabled'] = monitoring['k8s_metrics_enabled'];
    k8s_config['prometheus_admin_password'] = monitoring['prometheus_admin_password'];

    k8s_config['admin_username'] = self.get_admin_config().get('username', 'admin');

    backends = self.get_backends_config();
    k8s_config['backends'] = backends;
    managed_types = {
        entry['type']
        for entry in backends.values()
        if entry['source'] == 'managed'
    };
    k8s_config['mongodb_enabled'] = 'mongo' in managed_types;
    k8s_config['redis_enabled'] = 'redis' in managed_types;
    k8s_config['external_auth'] = self.get_external_auth_config();

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
    return {
        'port': int(server_config.get('port', 8000)),
        'host': server_config.get('host', '0.0.0.0'),
        'docs_enabled': server_config.get('docs_enabled', True),
        'suppress_health_check_logs': bool(
            server_config.get('suppress_health_check_logs', False)
        )
    };
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

    namespace = monitoring_config.get('namespace');
    if not namespace {
        k8s_config = config.get('kubernetes', {});
        k8s_namespace = k8s_config.get('namespace', 'default');
        namespace = sanitize_prometheus_namespace(k8s_namespace);
    }
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
    ws_redis_url = ws_config.get('redis_url')
    or self.get_database_config().get('redis_url');
    return {
        'backplane': backplane,
        'redis_url': ws_redis_url,
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
        return _scale_config_instance;
    }
    new_instance = JacScaleConfig(project_dir);
    _scale_config_instance = new_instance;
    return new_instance;
}

impl reset_scale_config -> None {
    _scale_config_instance = None;
}

impl resolve_password_hash_rounds(configured_rounds: int) -> int {
    env_val = os.environ.get('JAC_SCALE_BCRYPT_ROUNDS');
    if not env_val {
        return max(4, min(31, configured_rounds));
    }
    try {
        rounds = int(env_val);
    } except ValueError as e {
        raise ValueError(
            f"JAC_SCALE_BCRYPT_ROUNDS must be an integer in 4..31, got: {env_val!r}"
        ) from e;
    }
    return max(4, min(31, rounds));
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

impl JacScaleConfig.get_emailer_config(self: JacScaleConfig) -> dict[str, Any] {
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

impl JacScaleConfig.get_auth_config(self: JacScaleConfig) -> dict[str, Any] {
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
        'password_hash_rounds': resolve_password_hash_rounds(
            int(auth_config.get('password_hash_rounds', 12))
        ),
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

impl JacScaleConfig.get_microservices_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    return normalize_microservices_config(config.get('microservices', {}));
}


impl normalize_microservices_config(ms_config: dict[str, any]) -> dict[str, any] {
    client_config = ms_config.get('client', {});
    cors_config = ms_config.get('cors', {});
    rl_config = ms_config.get('rate_limit', {});

    routes: dict[str, any] = dict(ms_config.get('routes', {}));
    if not routes {
        import json;
        env_routes: str = os.environ.get('JAC_SV_ROUTES', '');
        if env_routes {
            try {
                routes = dict(json.loads(env_routes));
            } except Exception as e {
                import logging;
                logging.getLogger(__name__).warning(
                    f"Ignoring malformed JAC_SV_ROUTES env var ({e}); "
                    f"gateway will have no routes from env."
                );
                routes = {};
            }
        }
    }

    raw_client_entry = client_config.get('entry', None);
    if raw_client_entry is False {
        resolved_client_entry: str = '';
    } elif raw_client_entry {
        resolved_client_entry: str = str(raw_client_entry);
    } else {
        try {
            import from jaclang.project.config { get_config }
            resolved_client_entry: str = get_config().entry_point or 'main.jac';
        } except Exception {
            resolved_client_entry: str = 'main.jac';
        }
    }

    return {
        'enabled': ms_config.get('enabled', None),
        'gateway_port': int(ms_config.get('gateway_port', 8000)),
        'gateway_host': ms_config.get('gateway_host', '0.0.0.0'),
        'drain_timeout_seconds': float(ms_config.get('drain_timeout_seconds', 10)),
        'http_forward_timeout': float(ms_config.get('http_forward_timeout', 30)),
        'routes': routes,
        'services': dict(ms_config.get('services', {})),
        'rate_limit': {
            'enabled': bool(rl_config.get('enabled', False)),
            'per_ip_rpm': int(rl_config.get('per_ip_rpm', 60)),
            'per_user_rpm': int(rl_config.get('per_user_rpm', 0)),
            'burst_multiplier': float(rl_config.get('burst_multiplier', 2.0)),
            'exempt_paths': list(
                rl_config.get('exempt_paths', ["/health", "/healthz", "/metrics"])
            )
        },
        'cors': {
            'allow_origins': list(cors_config.get('allow_origins', ["*"])),
            'allow_methods': list(cors_config.get('allow_methods', ["*"])),
            'allow_headers': list(cors_config.get('allow_headers', ["*"])),
            'allow_credentials': bool(cors_config.get('allow_credentials', False)),
            'expose_headers': list(cors_config.get('expose_headers', [])),
            'max_age': int(cors_config.get('max_age', 600))
        },
        'client': {
            'entry': resolved_client_entry,
            'dist_dir': client_config.get('dist_dir', '.jac/client/dist'),
            'base_route': client_config.get('base_route', '/')
        },
        'ingress': dict(ms_config.get('ingress', {})),
        'shared_volumes': list(ms_config.get('shared_volumes', [])),
        'logs': dict(ms_config.get('logs', {})),
        'tracing': dict(ms_config.get('tracing', {}))
    };
}

impl JacScaleConfig.get_backends_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    raw_scale = self.get_jac_config().get_plugin_config('scale') or {};
    return normalize_backends_config(
        dict(config.get('database', {}) or {}),
        dict(raw_scale.get('kubernetes', {}) or {})
    );
}

impl JacScaleConfig.get_external_auth_config(self: JacScaleConfig) -> dict[str, any] {
    config = self.load();
    return normalize_external_auth_config(dict(config.get('auth', {}) or {}));
}

impl _default_backend_env(backend_type: str) -> str {
    import re;
    defaults = {
        'mongo': 'MONGODB_URI',
        'redis': 'REDIS_URL',
        'postgres': 'DATABASE_URL'
    };
    if backend_type in defaults {
        return defaults[backend_type];
    }
    slug = re.sub(r'[^A-Za-z0-9]+', '_', backend_type).strip('_').upper();
    return f"{slug or 'BACKEND'}_URL";
}

impl _backend_entry(name: str, spec: dict[str, any]) -> dict[str, any] {
    aliases = {'mongodb': 'mongo', 'postgresql': 'postgres'};
    allowed_keys = {'type', 'source', 'url', 'env'};
    unknown = sorted(set(spec.keys()) - allowed_keys);
    if unknown {
        raise ValueError(
            f"[scale.database.{name}] has unsupported key(s) "
            f"{', '.join(unknown)}; allowed: {', '.join(sorted(allowed_keys))}."
        );
    }

    backend_type = str(spec.get('type', '') or '').strip().lower();
    if not backend_type {
        raise ValueError(
            f"[scale.database.{name}] needs 'type' "
            f"(e.g. \"postgres\", \"redis\", \"mongo\")."
        );
    }
    backend_type = aliases.get(backend_type, backend_type);

    url = str(spec.get('url', '') or '').strip();
    source = str(spec.get('source', '') or '').strip().lower();
    if not source {
        source = 'external' if url else 'managed';
    }
    if source not in ('managed', 'external', 'disabled') {
        raise ValueError(
            f"[scale.database.{name}].source must be 'managed' (jac-scale "
            f"provisions it), 'external' (you run it, jac-scale wires 'url') "
            f"or 'disabled', got {source!r}."
        );
    }

    entry: dict[str, any] = {'type': backend_type, 'source': source};
    if source == 'managed' {
        if url {
            raise ValueError(
                f"[scale.database.{name}]: 'url' does not apply to a managed "
                f"backend - jac-scale provisions it and injects the URL itself. "
                f"Set source = \"external\" if you run this backend."
            );
        }
        if backend_type not in ('mongo', 'redis') {
            raise ValueError(
                f"[scale.database.{name}]: managed '{backend_type}' is not "
                f"supported yet (only mongo and redis); set "
                f"source = \"external\" and provide its url."
            );
        }
    } elif source == 'external' {
        if not url {
            raise ValueError(
                f"[scale.database.{name}] with source = \"external\" needs "
                f"'url'. Use env interpolation so credentials stay out of "
                f"jac.toml, e.g. url = \"${{DATABASE_URL}}\" with the value in "
                f".env or your CI environment."
            );
        }
        import re;
        unresolved = re.findall(r'\$\{([^}:]+)[^}]*\}', url);
        if unresolved {
            raise ValueError(
                f"[scale.database.{name}].url did not resolve: environment "
                f"variable(s) {', '.join(unresolved)} not set. Define them in "
                f".env or the deploy environment."
            );
        }
        entry['url'] = url;
        entry['env'] = str(spec.get('env', '') or '').strip()
            or _default_backend_env(backend_type);
    }
    return entry;
}

impl normalize_backends_config(
    database_cfg: dict[str, any], raw_kubernetes_cfg: dict[str, any]
) -> dict[str, any] {
    backends: dict[str, any] = {};
    for (raw_name, spec) in database_cfg.items() {
        if not isinstance(spec, dict) {
            continue;
        }
        entry = _backend_entry(str(raw_name), dict(spec));
        if entry['source'] == 'disabled' {
            continue;
        }
        backends[str(raw_name)] = entry;
    }

    if backends {
        _guard_backend_conflicts(backends);
        import logging;
        for flag_name in ('mongodb_enabled', 'redis_enabled') {
            if raw_kubernetes_cfg.get(flag_name) is not None {
                logging.getLogger(__name__).warning(
                    f"[scale.kubernetes].{flag_name} is ignored: [scale.database] "
                    f"declares backends, and that declaration is the complete "
                    f"inventory."
                );
            }
        }
        return backends;
    }

    provision_all = database_cfg.get('provision');
    legacy_flags = {
        'mongo': raw_kubernetes_cfg.get('mongodb_enabled'),
        'redis': raw_kubernetes_cfg.get('redis_enabled')
    };
    for (backend_type, flag) in legacy_flags.items() {
        provisioned = (flag is not False)
            if provision_all is None
            else bool(provision_all);
        if provisioned {
            backends[backend_type] = {'type': backend_type, 'source': 'managed'};
        }
    }
    return backends;
}

impl _guard_backend_conflicts(backends: dict[str, any]) -> None {
    managed_types: dict[str, str] = {};
    env_names: dict[str, str] = {};
    for (name, entry) in backends.items() {
        if entry['source'] == 'managed' {
            if entry['type'] in managed_types {
                raise ValueError(
                    f"[scale.database] declares two managed '{entry['type']}' "
                    f"backends ('{managed_types[entry['type']]}' and '{name}'); "
                    f"only one managed instance per type is supported."
                );
            }
            managed_types[entry['type']] = name;
        } else {
            env = entry['env'];
            if env in env_names {
                raise ValueError(
                    f"[scale.database] backends '{env_names[env]}' and '{name}' "
                    f"both inject the env var '{env}'; set a distinct 'env' on "
                    f"one of them."
                );
            }
            env_names[env] = name;
        }
    }
}

impl normalize_external_auth_config(auth_cfg: dict[str, any]) -> dict[str, any] {
    auth_type = str(auth_cfg.get('type', 'managed') or 'managed').strip().lower();
    if auth_type not in ('managed', 'custom') {
        raise ValueError(
            f"[scale.auth].type must be 'managed' (jac-scale mounts its "
            f"/user/* auth) or 'custom' (the app handles auth itself), "
            f"got {auth_type!r}."
        );
    }
    return {
        'type': auth_type,
        'issuer': str(auth_cfg.get('issuer', '') or '').strip(),
        'jwks_url': str(auth_cfg.get('jwks_url', '') or '').strip(),
        'audience': str(auth_cfg.get('audience', '') or '').strip()
    };
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
