"""Plugin configuration hooks for jac-scale.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.scale] section
"""

import from typing { Any }
import from jaclang.jac0core.runtime { hookimpl }

"""Plugin configuration hooks for jac-scale."""
class JacScalePluginConfig {
    """Return plugin metadata."""
    @hookimpl
    static def get_plugin_metadata -> dict[str, Any] {
        return {
            "name": "scale",
            "version": "0.1.0",
            "description": "Jac Scale - Deploy and scale Jac applications with Kubernetes"
        };
    }

    """Return the plugin's configuration schema for [plugins.scale]."""
    @hookimpl
    static def get_config_schema -> dict[str, Any] {
        return {
            "section": "scale",
            "options": {
                "jwt": {
                    "type": "dict",
                    "default": {},
                    "description": "JWT authentication configuration",
                    "nested": {
                        "secret": {
                            "type": "string",
                            "default": "supersecretkey_for_testing_only!",
                            "description": "Secret key for JWT signing"
                        },
                        "algorithm": {
                            "type": "string",
                            "default": "HS256",
                            "description": "JWT encoding algorithm"
                        },
                        "exp_delta_days": {
                            "type": "int",
                            "default": 7,
                            "description": "JWT token expiration in days"
                        }
                    }
                },
                "sso": {
                    "type": "dict",
                    "default": {},
                    "description": "SSO authentication configuration",
                    "nested": {
                        "host": {
                            "type": "string",
                            "default": "http://localhost:8000/sso",
                            "description": "SSO callback host URL"
                        },
                        "google": {
                            "type": "dict",
                            "default": {},
                            "description": "Google OAuth configuration",
                            "nested": {
                                "client_id": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Google OAuth client ID"
                                },
                                "client_secret": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Google OAuth client secret"
                                }
                            }
                        }
                    }
                },
                "database": {
                    "type": "dict",
                    "default": {},
                    "description": "Database connection configuration",
                    "nested": {
                        "mongodb_uri": {
                            "type": "string",
                            "default": None,
                            "description": "MongoDB connection URI"
                        },
                        "redis_url": {
                            "type": "string",
                            "default": None,
                            "description": "Redis connection URL"
                        },
                        "shelf_db_path": {
                            "type": "string",
                            "default": ".jac/data/anchor_store.db",
                            "description": "File-based storage path for ShelfDB fallback"
                        }
                    }
                },
                "kubernetes": {
                    "type": "dict",
                    "default": {},
                    "description": "Kubernetes deployment configuration",
                    "nested": {
                        "app_name": {
                            "type": "string",
                            "default": "jaseci",
                            "description": "Application name for Kubernetes resources"
                        },
                        "docker_image_name": {
                            "type": "string",
                            "default": "",
                            "description": "Docker image name (defaults to {app_name}:latest)"
                        },
                        "docker_username": {
                            "type": "string",
                            "default": "",
                            "description": "DockerHub username for pushing images"
                        },
                        "docker_password": {
                            "type": "string",
                            "default": "",
                            "description": "DockerHub password/token for pushing images"
                        },
                        "namespace": {
                            "type": "string",
                            "default": "default",
                            "description": "Kubernetes namespace for deployment"
                        },
                        "container_port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Container port for the application"
                        },
                        "node_port": {
                            "type": "int",
                            "default": 30001,
                            "description": "NodePort for external access"
                        },
                        "mongodb_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable MongoDB deployment in Kubernetes"
                        },
                        "redis_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable Redis deployment in Kubernetes"
                        },
                        "plugin_versions": {
                            "type": "dict",
                            "default": {},
                            "description": "Package versions for PyPI installation (default mode). Use 'latest' or specific version.",
                            "nested": {
                                "jaclang": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jaclang package version"
                                },
                                "jac_scale": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jac-scale package version"
                                },
                                "jac_client": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jac-client package version"
                                },
                                "jac_byllm": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jac-byllm package version (use 'none' to skip)"
                                }
                            }
                        },

                    }
                },
                "secrets": {
                    "type": "dict",
                    "default": {},
                    "description": "Environment variable secrets for K8s deployment. Values use ${ENV_VAR} syntax, resolved at deploy time and created as a K8s Secret with envFrom.secretRef."
                },
                "server": {
                    "type": "dict",
                    "default": {},
                    "description": "Server configuration",
                    "nested": {
                        "port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Server port"
                        },
                        "host": {
                            "type": "string",
                            "default": "0.0.0.0",
                            "description": "Server host"
                        }
                    }
                },
                "monitoring": {
                    "type": "dict",
                    "default": {},
                    "description": "Monitoring configuration for the HTTP /metrics endpoint and Kubernetes Prometheus + Grafana stack",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable Prometheus metrics collection, /metrics endpoint, and Kubernetes monitoring stack"
                        },
                        "endpoint": {
                            "type": "string",
                            "default": "/metrics",
                            "description": "Path for the Prometheus metrics endpoint"
                        },
                        "namespace": {
                            "type": "string",
                            "default": "jac_scale",
                            "description": "Metrics namespace prefix (e.g., myapp_http_requests_total)"
                        },
                        "walker_metrics": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable walker execution timing metrics"
                        },
                        "histogram_buckets": {
                            "type": "list",
                            "default": [
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
                            "description": "Histogram bucket boundaries in seconds for latency metrics"
                        },
                        "prometheus_admin_password": {
                            "type": "string",
                            "default": "Adminpassword123",
                            "description": "Admin password for Grafana when deploying the monitoring stack"
                        },
                        "prometheus_node_port": {
                            "type": "int",
                            "default": 30090,
                            "description": "NodePort for Prometheus when deploying the monitoring stack"
                        },
                        "grafana_node_port": {
                            "type": "int",
                            "default": 30300,
                            "description": "NodePort for Grafana when deploying the monitoring stack"
                        }
                    }
                }
            }
        };
    }
}
