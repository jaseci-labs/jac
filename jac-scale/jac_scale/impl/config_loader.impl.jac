"""Implementation of Jac Scale configuration loader.

This module provides the implementation for JacScaleConfig, which inherits
from PluginConfigBase for common configuration loading functionality.

The base class handles: init, load, get_jac_config, deep_merge, get_section.
This file only implements plugin-specific methods.
"""
import from pathlib { Path }
import from typing { Any }
import os;

"""Get the plugin section name for scale."""
impl JacScaleConfig.get_plugin_name(self: JacScaleConfig) -> str {
    return "scale";
}

"""Get default configuration structure for scale."""
impl JacScaleConfig.get_default_config(self: JacScaleConfig) -> dict[str, Any] {
    return {
        'jwt': {
            'secret': 'supersecretkey_for_testing_only!',
            'algorithm': 'HS256',
            'exp_delta_days': 7
        },
        'sso': {
            'host': 'http://localhost:8000/sso',
            'google': {'client_id': '', 'client_secret': ''}
        },
        'database': {
            'mongodb_uri': None,
            'redis_url': None,
            'shelf_db_path': '.jac/data/anchor_store.db'
        },
        'kubernetes': {
            'app_name': 'jaseci',
            'docker_image_name': '',
            'docker_username': '',
            'docker_password': '',
            'namespace': 'default',
            'container_port': 8000,
            'node_port': 30001,
            'mongodb_enabled': True,
            'redis_enabled': True,
            # Resource requests/limits
            'cpu_request': None,
            'cpu_limit': None,
            'memory_request': None,
            'memory_limit': None,
            # Probe timings
            'readiness_initial_delay': 10,
            'readiness_period': 20,
            'liveness_initial_delay': 10,
            'liveness_period': 20,
            'liveness_failure_threshold': 80
        },
        'secrets': {},
        'server': {'port': 8000, 'host': '0.0.0.0'},
        'webhook': {
            'secret': 'webhook-secret-key',
            'signature_header': 'X-Webhook-Signature',
            'verify_signature': True,
            'api_key_expiry_days': 365
        },
        'monitoring': {
            'enabled': False,
            'endpoint': '/metrics',
            'namespace': 'jac_scale',
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
            'prometheus_node_port': 30090,
            'grafana_node_port': 30300
        }
    };
}

"""Get JWT configuration from jac.toml."""
impl JacScaleConfig.get_jwt_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    jwt_config = config.get('jwt', {});
    return {
        'secret': jwt_config.get('secret', 'supersecretkey_for_testing_only!'),
        'algorithm': jwt_config.get('algorithm', 'HS256'),
        'exp_delta_days': int(jwt_config.get('exp_delta_days', 7))
    };
}

"""Get SSO configuration from jac.toml."""
impl JacScaleConfig.get_sso_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    sso_config = config.get('sso', {});
    google_config = sso_config.get('google', {});
    return {
        'host': sso_config.get('host', 'http://localhost:8000/sso'),
        'google': {
            'client_id': google_config.get('client_id', ''),
            'client_secret': google_config.get('client_secret', '')
        }
    };
}

"""Get database configuration from jac.toml."""
impl JacScaleConfig.get_database_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    db_config = config.get('database', {});
    return {
        'mongodb_uri': os.environ.get('MONGODB_URI') or db_config.get('mongodb_uri'),
        'redis_url': os.environ.get('REDIS_URL') or db_config.get('redis_url'),
        'shelf_db_path': db_config.get('shelf_db_path', '.jac/data/anchor_store.db')
    };
}

"""Get Kubernetes configuration from jac.toml."""
impl JacScaleConfig.get_kubernetes_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    k8s_config = config.get('kubernetes', {});
    # Handle docker_image_name default (needs app_name)
    if not k8s_config.get('docker_image_name') {
        app_name = k8s_config.get('app_name', 'jaseci');
        k8s_config['docker_image_name'] = f"{app_name}:latest";
    }
    # Merge monitoring config into kubernetes config
    monitoring = self.get_monitoring_config();
    k8s_config['monitoring_enabled'] = monitoring['enabled'];
    k8s_config['prometheus_admin_password'] = monitoring['prometheus_admin_password'];
    k8s_config['prometheus_node_port'] = monitoring['prometheus_node_port'];
    k8s_config['grafana_node_port'] = monitoring['grafana_node_port'];
    # Convert to dict using KubernetesConfig.from_dict() which handles all defaults
    import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
    k8s_config_obj = KubernetesConfig.from_dict(KubernetesConfig, k8s_config);
    return k8s_config_obj.to_dict();
}

"""Get server configuration from jac.toml."""
impl JacScaleConfig.get_server_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    server_config = config.get('server', {});
    return {
        'port': int(server_config.get('port', 8000)),
        'host': server_config.get('host', '0.0.0.0')
    };
}

"""Get webhook configuration from jac.toml."""
impl JacScaleConfig.get_webhook_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    webhook_config = config.get('webhook', {});
    return {
        'signature_header': webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        ),
        'verify_signature': webhook_config.get('verify_signature', True),
        'api_key_expiry_days': int(webhook_config.get('api_key_expiry_days', 365))
    };
}

"""Get secrets from [plugins.scale.secrets] section.

Values using ${ENV_VAR} syntax are auto-resolved by core's interpolate_env_vars.
"""
impl JacScaleConfig.get_secrets_config(self: JacScaleConfig) -> dict[str, str] {
    config = self.load();
    return config.get('secrets', {});
}

"""Sanitize a string to be a valid Prometheus metric namespace.

Prometheus metric names must match [a-zA-Z_:][a-zA-Z0-9_:]*.
This converts any invalid characters and ensures a valid prefix.
"""
impl sanitize_prometheus_namespace(name: str) -> str {
    import re;
    # Replace any non-alphanumeric characters with underscores
    sanitized = re.sub(r'[^a-zA-Z0-9]', '_', name);
    # Collapse multiple consecutive underscores
    sanitized = re.sub(r'_+', '_', sanitized);
    # Strip leading/trailing underscores
    sanitized = sanitized.strip('_');
    # Prefix with underscore if starts with digit
    if sanitized and sanitized[0].isdigit() {
        sanitized = f"_{sanitized}";
    }
    return sanitized or 'jac_scale';
}

"""Get monitoring configuration from jac.toml.

Combines HTTP metrics endpoint settings and Kubernetes monitoring stack settings.
'enabled' controls both the /metrics endpoint and Prometheus + Grafana deployment.
"""
impl JacScaleConfig.get_monitoring_config(self: JacScaleConfig) -> dict[str, Any] {
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
    # Derive namespace from kubernetes config if not explicitly set
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
        'prometheus_admin_password': monitoring_config.get(
            'prometheus_admin_password', 'Adminpassword123'
        ),
        'prometheus_node_port': int(
            monitoring_config.get('prometheus_node_port', 30090)
        ),
        'grafana_node_port': int(monitoring_config.get('grafana_node_port', 30300))
    };
}

"""Get or create the global JacScaleConfig instance."""
impl get_scale_config(project_dir: Path | None = None) -> JacScaleConfig {
    global _scale_config_instance;
    if _scale_config_instance is None {
        _scale_config_instance = JacScaleConfig(project_dir);
    }
    return _scale_config_instance;
}

"""Reset the global config instance (useful for testing)."""
impl reset_scale_config -> None {
    global _scale_config_instance;
    _scale_config_instance = None;
}
