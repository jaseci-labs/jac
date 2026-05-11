"""Plugin configuration hooks for jac-scale."""
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
                "microservices": {
                    "type": "dict",
                    "default": {},
                    "description": "Microservice mode - run declared Jac files as independent service processes behind an API gateway",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable microservice mode (off by default). Use `jac setup microservice` to configure."
                        },
                        "gateway_port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Gateway port (external-facing)"
                        },
                        "gateway_host": {
                            "type": "string",
                            "default": "0.0.0.0",
                            "description": "Gateway host"
                        },
                        "drain_timeout_seconds": {
                            "type": "float",
                            "default": 10.0,
                            "description": "Graceful shutdown window (seconds). On SIGTERM, gateway + services flip a drain flag (503s on new requests) and wait up to this many seconds for in-flight requests to finish before uvicorn force-closes. Mirrors K8s `terminationGracePeriodSeconds`."
                        },
                        "http_forward_timeout": {
                            "type": "float",
                            "default": 30.0,
                            "description": "Gateway-to-service forward timeout (seconds). Applies to `raw_forward` (built-in passthrough fan-out) and `stream_forward` (path-routed proxy). Distinct from `services.NAME.rpc_timeout`, which controls inter-service `sv import` calls. Override per-service with `[plugins.scale.microservices.services.NAME].http_forward_timeout`."
                        },
                        "routes": {
                            "type": "dict",
                            "default": {},
                            "description": "Module-name -> gateway-prefix map. Services are discovered via `sv import`; this only controls client-facing URL routing."
                        },
                        "services": {
                            "type": "dict",
                            "default": {},
                            "description": "Per-service overrides keyed by module name. Each subkey is a dict with optional `rpc_timeout` (float seconds; default 10s; controls inter-service `sv import` httpx calls) and/or `http_forward_timeout` (float seconds; default 30s; controls gateway-to-service aiohttp forwarding). Use for LLM/long-running services that need minutes, not seconds. Example: [plugins.scale.microservices.services.llm_app] rpc_timeout = 120.0, http_forward_timeout = 300.0"
                        },
                        "rate_limit": {
                            "type": "dict",
                            "default": {},
                            "description": "Gateway rate limiting (token bucket). Disabled unless `enabled = true`.",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Master switch."
                                },
                                "per_ip_rpm": {
                                    "type": "int",
                                    "default": 60,
                                    "description": "Requests per minute per client IP. 0 disables per-IP limit."
                                },
                                "per_user_rpm": {
                                    "type": "int",
                                    "default": 0,
                                    "description": "Additional requests per minute per authenticated user (keyed by Authorization header hash). 0 disables per-user limit."
                                },
                                "burst_multiplier": {
                                    "type": "float",
                                    "default": 2.0,
                                    "description": "Bucket capacity = rpm * burst_multiplier / 60 (allows short bursts above the steady rate)."
                                },
                                "exempt_paths": {
                                    "type": "list",
                                    "default": ["/health", "/healthz", "/metrics"],
                                    "description": "Paths that bypass rate limiting entirely (monitoring + probes)."
                                }
                            }
                        },
                        "cors": {
                            "type": "dict",
                            "default": {},
                            "description": "CORS middleware on the gateway. Open by default (any origin). Set `allow_origins = []` to disable, or provide a concrete list to restrict.",
                            "nested": {
                                "allow_origins": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "Origins that may access the gateway. Default [\"*\"] allows any. Empty list disables CORS."
                                },
                                "allow_methods": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "HTTP methods allowed on cross-origin requests."
                                },
                                "allow_headers": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "Request headers allowed on cross-origin requests."
                                },
                                "allow_credentials": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Allow cookies / Authorization on cross-origin requests. Incompatible with allow_origins = [\"*\"] per spec."
                                },
                                "expose_headers": {
                                    "type": "list",
                                    "default": [],
                                    "description": "Response headers the browser is allowed to read across origins."
                                },
                                "max_age": {
                                    "type": "int",
                                    "default": 600,
                                    "description": "How long (seconds) the browser may cache a preflight response."
                                }
                            }
                        },
                        "client": {
                            "type": "dict",
                            "default": {},
                            "description": "Client UI build settings (optional)",
                            "nested": {
                                "entry": {
                                    "type": "string",
                                    "default": "",
                                    "description": "jac-client entry point (e.g., client/main.jac)"
                                },
                                "dist_dir": {
                                    "type": "string",
                                    "default": ".jac/client/dist",
                                    "description": "Build output directory for static assets"
                                },
                                "base_route": {
                                    "type": "string",
                                    "default": "/",
                                    "description": "SPA base route"
                                }
                            }
                        }
                    }
                },
                "events": {
                    "type": "dict",
                    "default": {},
                    "description": "Event-streaming broker configuration. Off by default. When enabled, jac-scale exposes publish() / @subscribe via the active broker (RedisBroker if a redis URL resolves, otherwise LocalBroker in-memory).",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable the event-streaming broker. When false, all publish() calls become no-ops."
                        },
                        "url": {
                            "type": "string",
                            "default": None,
                            "description": "Redis connection URL. If unset, falls back to [plugins.scale.database].redis_url. If neither is set or `redis` extra is missing, LocalBroker (in-memory) is used."
                        },
                        "consumer_group": {
                            "type": "string",
                            "default": "jac-scale",
                            "description": "Default consumer group name used when @subscribe does not specify one."
                        },
                        "serializer": {
                            "type": "string",
                            "default": "json",
                            "description": "Payload serializer: 'json' (default) or 'msgpack' (requires extra)."
                        },
                        "retry": {
                            "type": "dict",
                            "default": {},
                            "description": "Default retry policy applied when a subscription does not provide its own.",
                            "nested": {
                                "max_attempts": {
                                    "type": "int",
                                    "default": 3,
                                    "description": "Number of delivery attempts before the message is sent to the dead-letter topic."
                                },
                                "backoff_seconds": {
                                    "type": "list",
                                    "default": [1.0, 5.0, 30.0],
                                    "description": "Backoff delays per attempt index, clamped to the last value."
                                },
                                "dead_letter_suffix": {
                                    "type": "string",
                                    "default": ".dlq",
                                    "description": "Suffix appended to the topic name to form its dead-letter topic."
                                }
                            }
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
                        }
                    }
                }
            }
        };
    }
}
