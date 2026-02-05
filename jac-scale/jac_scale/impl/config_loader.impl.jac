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
        'server': {'port': 8000, 'host': '0.0.0.0'},
        'webhook': {
            'secret': 'webhook-secret-key',
            'signature_header': 'X-Webhook-Signature',
            'verify_signature': True,
            'api_key_expiry_days': 365
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
        'secret': os.environ.get('WEBHOOK_SECRET')
        or webhook_config.get('secret', 'webhook-secret-key'),
        'signature_header': webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        ),
        'verify_signature': webhook_config.get('verify_signature', True),
        'api_key_expiry_days': int(webhook_config.get('api_key_expiry_days', 365))
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
