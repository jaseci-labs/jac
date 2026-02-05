"""Plugin configuration hooks for jac-scale.

This module implements JacPluginConfig hooks to integrate with core's
configuration system, registering:
- Plugin metadata (name, version)
- Config schema for [plugins.scale] section
"""

import from typing { Any }
import from jaclang.pycore.runtime { hookimpl }

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
                        }
                    }
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
                }
            }
        };
    }
}
