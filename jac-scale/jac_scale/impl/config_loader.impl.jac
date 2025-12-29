"""Implementation of Jac Scale configuration loader.

This module provides the implementation for JacScaleConfig, which inherits
from PluginConfigBase for common configuration loading functionality.

The base class handles: init, load, get_jac_config, deep_merge, get_section.
This file only implements plugin-specific methods.
"""
import from pathlib { Path }
import from typing { Any }

"""Get the plugin section name for scale."""
impl JacScaleConfig.get_plugin_name(self: JacScaleConfig) -> str {
    return "scale";
}

"""Get default configuration structure for scale."""
impl JacScaleConfig.get_default_config(self: JacScaleConfig) -> dict[str, Any] {
    return {
        'jwt': {'secret': 'supersecretkey', 'algorithm': 'HS256', 'exp_delta_days': 7},
        'sso': {
            'host': 'http://localhost:8000/sso',
            'google': {'client_id': '', 'client_secret': ''}
        },
        'database': {
            'mongodb_uri': 'mongodb://root:rootpassword123@localhost:27017/',
            'redis_url': 'redis://:mypassword123@localhost:6379/0',
            'shelf_db_path': 'anchor_store.db'
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
            'redis_enabled': True
        },
        'server': {'port': 8000, 'host': '0.0.0.0'}
    };
}

"""Get JWT configuration from jac.toml."""
impl JacScaleConfig.get_jwt_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    jwt_config = config.get('jwt', {});
    return {
        'secret': jwt_config.get('secret', 'supersecretkey'),
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
        'mongodb_uri': db_config.get(
            'mongodb_uri', 'mongodb://root:rootpassword123@localhost:27017/'
        ),
        'redis_url': db_config.get(
            'redis_url', 'redis://:mypassword123@localhost:6379/0'
        ),
        'shelf_db_path': db_config.get('shelf_db_path', 'anchor_store.db')
    };
}

"""Get Kubernetes configuration from jac.toml."""
impl JacScaleConfig.get_kubernetes_config(self: JacScaleConfig) -> dict[str, Any] {
    config = self.load();
    k8s_config = config.get('kubernetes', {});
    app_name = k8s_config.get('app_name', 'jaseci');
    default_image = f"{app_name}:latest";
    return {
        'app_name': app_name,
        'docker_image_name': k8s_config.get('docker_image_name', default_image),
        'docker_username': k8s_config.get('docker_username', ''),
        'docker_password': k8s_config.get('docker_password', ''),
        'namespace': k8s_config.get('namespace', 'default'),
        'container_port': int(k8s_config.get('container_port', 8000)),
        'node_port': int(k8s_config.get('node_port', 30001)),
        'mongodb_enabled': bool(k8s_config.get('mongodb_enabled', True)),
        'redis_enabled': bool(k8s_config.get('redis_enabled', True))
    };
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

"""Get or create the global JacScaleConfig instance."""
impl get_scale_config(project_dir: Path | None = None) -> JacScaleConfig {
    global _scale_config_instance;
    if _scale_config_instance is None {
        _scale_config_instance = JacScaleConfig(project_dir);
    }
    return _scale_config_instance;
}

"""Reset the global config instance (useful for testing)."""
impl reset_scale_config()  -> None {
    global _scale_config_instance;
    _scale_config_instance = None;
}
