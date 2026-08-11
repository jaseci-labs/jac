class JacScalePluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "scale",
            "version": "0.1.0",
            "description": "Jac Scale - Deploy and scale Jac applications with Kubernetes"
        };
    }

    static def get_config_schema -> dict[str, any] {
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
                        "url": {
                            "type": "string",
                            "default": None,
                            "description": "Postgres connection URL (postgresql://user:pass@host:port/db). Also honored via the JAC_DB_URL env var. When set, in-cluster provisioning is skipped (external mode)."
                        },
                        "deploy_mode": {
                            "type": "string",
                            "default": "image",
                            "description": "How the k8s target runs Postgres: 'image' (official postgres image), 'embedded' (the app's jac image running `jac db serve`), or implicit 'external' when url is set."
                        },
                        "postgres_image": {
                            "type": "string",
                            "default": "postgres:18",
                            "description": "Image used in deploy_mode='image'."
                        },
                        "postgres_storage": {
                            "type": "string",
                            "default": "2Gi",
                            "description": "PVC size for the provisioned Postgres StatefulSet. Must be a valid Kubernetes quantity, e.g. 2Gi."
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
                            "default": None,
                            "description": "Application name for Kubernetes resources. Defaults to a k8s-safe slug of [project].name when unset, or 'jaseci' if no project name is usable"
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
                        "postgres_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Provision Postgres in Kubernetes (disable when using an external database url)"
                        },
                        "autoscaler_engine": {
                            "type": "string",
                            "default": "hpa",
                            "description": "Autoscaler engine to use. Built-in: 'hpa' (default, CPU/memory only) or 'keda' (event-driven, supports scale-to-zero). External plugins can register additional engines via AutoscalerFactory.register()."
                        },
                        "min_replicas": {
                            "type": "int",
                            "default": 1,
                            "description": "Minimum pod replicas for the autoscaler."
                        },
                        "max_replicas": {
                            "type": "int",
                            "default": 3,
                            "description": "Maximum pod replicas for the autoscaler."
                        },
                        "cpu_utilization_target": {
                            "type": "int",
                            "default": 50,
                            "description": "CPU utilization percentage for the HPA cpu trigger (engine='hpa') or the KEDA cpu trigger when no explicit cpu trigger is listed. Ignored when engine='keda' and at least one non-cpu trigger is configured without a cpu trigger."
                        },
                        "memory_utilization_target": {
                            "type": "int",
                            "default": 80,
                            "description": "Memory utilization percentage (of the container memory request) for the default memory trigger, so pods scale out before hitting their memory limit instead of getting OOM-killed. Applied alongside cpu_utilization_target when no explicit triggers are configured."
                        },
                        "autoscaler_scale_up_stabilization": {
                            "type": "int",
                            "default": 60,
                            "description": "HPA scale-up stabilization window in seconds. Prevents the Kubernetes default (double the fleet every 15s) from bursting pods faster than nodes can absorb their memory."
                        },
                        "autoscaler_scale_up_max_pods": {
                            "type": "int",
                            "default": 2,
                            "description": "Maximum pods the autoscaler may add per minute. Rate-limits scale-up so a traffic spike cannot OOM the node with a burst of booting pods."
                        },
                        "idle_replicas": {
                            "type": "int",
                            "default": None,
                            "description": "(KEDA only) Replica count when all triggers go inactive. Set to 0 for scale-to-zero. Omit (null) to fall back to min_replicas."
                        },
                        "autoscaler_polling_interval": {
                            "type": "int",
                            "default": 30,
                            "description": "(KEDA only) How often KEDA evaluates triggers, in seconds."
                        },
                        "autoscaler_cooldown": {
                            "type": "int",
                            "default": 300,
                            "description": "Seconds of continuous inactivity before scaling down to idle_replicas (KEDA); also used as the HPA scale-down stabilization window on both engines."
                        },
                        "autoscaler_initial_cooldown": {
                            "type": "int",
                            "default": 0,
                            "description": "(KEDA only) Delay after a fresh deploy before scale-to-zero becomes eligible. Prevents cold-start thrash on slow-booting apps."
                        },
                        "extra_triggers": {
                            "type": "list",
                            "default": [],
                            "description": "(KEDA only) Additional KEDA trigger dicts applied to every service. Each entry: `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). For per-service triggers use [[scale.microservices.services.NAME.triggers]] instead."
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
                        },
                        "suppress_health_check_logs": {
                            "type": "bool",
                            "default": False,
                            "description": "Suppress health-check endpoint access log entries (/docs, /, /openapi.json, /health, /healthz, /healthz/ready, /healthz/live) from CLI output and Kubernetes pod logs. Off by default."
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
                            "description": "Deprecated - declaring [scale.microservices.routes] is what turns microservice mode on; set false to force single-process while keeping the routes table. Ignored inside deployed fleet pods (the deploy already realized the topology). A future release removes this key."
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
                            "description": "Graceful shutdown window (seconds). On SIGTERM, gateway + services flip a drain flag (503s on new requests) and wait up to this many seconds for in-flight requests to finish before the server force-closes; the serving core mirrors K8s `terminationGracePeriodSeconds`."
                        },
                        "http_forward_timeout": {
                            "type": "float",
                            "default": 30.0,
                            "description": "Gateway-to-service forward timeout (seconds). Applies to `raw_forward` (built-in passthrough fan-out) and `stream_forward` (path-routed proxy). Distinct from `services.NAME.rpc_timeout`, which controls inter-service RPC calls. Override per-service with `[scale.microservices.services.NAME].http_forward_timeout`."
                        },
                        "ingress": {
                            "type": "dict",
                            "default": {},
                            "description": "Optional K8s Ingress for the gateway. Default off (no Ingress emitted) so existing deployments don't grow one unexpectedly. Subkeys: `enabled` (bool, opt-in), `host` (str, omitted means match-any-host), `ingress_class_name` (str, e.g. \"nginx\", \"alb\", \"gce\"), `annotations` (dict[str,str], controller-specific knobs like nginx.ingress.kubernetes.io/proxy-body-size). HTTP only - TLS via cert-manager / ACM is deployment-specific. Routes all external traffic to gateway-service:container_port; the gateway dispatches /<svc>/* internally (member-subpath; the /api prefix was dropped)."
                        },
                        "routes": {
                            "type": "dict",
                            "default": {},
                            "description": "The service cut: module-name -> gateway-prefix map. Each key runs as its own service process (or pod) behind the gateway; an empty prefix derives /<module-slug>. This table is the single source of truth for which modules are services (`jac scale split <module>` adds an entry)."
                        },
                        "services": {
                            "type": "dict",
                            "default": {},
                            "description": "Per-service overrides keyed by module name. Subkeys (all optional): `file` (str, the service's entry file relative to the project root; default `<name>.jac`), `rpc_timeout` (float, default 10s, inter-service RPC calls), `http_forward_timeout` (float, default 30s, gateway-to-service forward), `replicas` (int, default 1, K8s Deployment.spec.replicas), `cpu_request` / `cpu_limit` (str, e.g. \"100m\", K8s container resources), `memory_request` / `memory_limit` (str, e.g. \"128Mi\"), `env` (dict[str,str], extra container env vars merged with auto-set JAC_SV_NAME), and nested `hpa` / `pdb` sub-tables. `hpa` keys: `enabled` (bool, default true), `min` (int, default 1), `max` (int, default 3), `cpu_target` (int percent, default 50), `memory_target` (int percent of memory request, default 80), `behavior` (table, default `{}`): a raw HPA `behavior` fragment (`scaleUp`/`scaleDown`, each with `stabilizationWindowSeconds`/`policies`/`selectPolicy`) deep-merged over the generated scale-rate defaults - same merge semantics as `deployment_overlay` (maps merge recursively, the `policies` list has no `name` key so it replaces wholesale rather than merging by entry); applies to both \"hpa\" and \"keda\" engines since both route through the same `Autoscaler._build_behavior` (for keda it only governs scaling above zero replicas - the drop to zero remains controlled by `autoscaler_cooldown`, the ScaledObject's cooldownPeriod). Use it to slow scale-down for connection-heavy services (e.g. `[services.NAME.hpa.behavior.scaleDown] stabilizationWindowSeconds = 600, selectPolicy = 'Min', policies = [{ type = 'Pods', value = 2, periodSeconds = 300 }]`) without imposing the same rate limit on every service via the app-global `autoscaler_cooldown`. `pdb` keys: `enabled` (bool, default true), `max_unavailable` (int, default 1). `deployment_overlay` (table): a raw Deployment-manifest fragment merged into the generated manifest at build time - maps merge recursively, lists whose members all carry `name` (containers, volumes, env, initContainers, volumeMounts) merge by that name, anything else replaces; identity fields (metadata.name/namespace, selector, the app/managed template labels) are reasserted after the merge. The main container's `name` is the k8s-safe service name (e.g. `builder-sv`; gateway is `gateway`). Use it for nodeSelector, probe tuning, extra volumes/env/init containers - anything the schema has no first-class key for - so pods are right on the FIRST rollout instead of being kubectl-patched into a second one. Overlays add and override only: there is no delete directive (setting a key to null stores null rather than removing the generated field). Gateway uses the `__gateway__` key. `[[services.NAME.triggers]]` array (KEDA only): per-service event-driven triggers; each entry has `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). Requires `autoscaler_engine = \"keda\"` in [scale.kubernetes]. Example: [scale.microservices.services.llm_app] rpc_timeout = 120.0, replicas = 2, cpu_limit = \"2000m\", memory_limit = \"4Gi\", env = { LOG_LEVEL = \"DEBUG\" }, [scale.microservices.services.llm_app.hpa] max = 20, cpu_target = 60"
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
                        },
                        "logs": {
                            "type": "dict",
                            "default": {},
                            "description": "Centralised log aggregation via Loki + Grafana Alloy (M-14). Off by default. When enabled, deploys the full monitoring stack (Prometheus + Grafana + Loki + Alloy) into the app namespace; Alloy tails every pod's stdout/stderr from `/var/log/pods` and ships to Loki, queried via Grafana's `Pod Logs` dashboard. v0 uses ephemeral `emptyDir` for Loki storage (suitable for dev/staging); persistent backends land in M-14.c. **Multi-tenant note**: Alloy's ClusterRole reads pods cluster-wide and the dashboard query is `{namespace=~\".+\"}`, so anyone with Grafana access sees logs from every namespace - change the default Grafana password and only enable on clusters where this exposure is acceptable.",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Enable the Loki + Alloy logging pipeline. Implies the full monitoring stack (Prometheus + Grafana) because the Pod Logs dashboard view lives in Grafana."
                                }
                            }
                        }
                    }
                },
                "websocket": {
                    "type": "dict",
                    "default": {},
                    "description": "WebSocket serving limits and the cross-pod broadcast backplane",
                    "nested": {
                        "backplane": {
                            "type": "string",
                            "default": None,
                            "description": "Broadcast backplane: 'memory' (single-pod, in-process fan-out) or 'pg' (cross-pod fan-out over Postgres LISTEN/NOTIFY). Unset auto-selects 'pg' when a scale database resolves, else 'memory'."
                        },
                        "allowed_origins": {
                            "type": "list",
                            "default": [],
                            "description": "Origins allowed to open cross-origin WebSocket upgrades. Default [] refuses cross-origin browsers (same-origin and non-browser clients always pass); list origins explicitly or use [\"*\"] to allow any."
                        },
                        "max_message_bytes": {
                            "type": "int",
                            "default": 65536,
                            "description": "Maximum decoded inbound WebSocket message size in bytes; larger messages are rejected and the connection closed."
                        },
                        "max_connections_per_target": {
                            "type": "int",
                            "default": 5000,
                            "description": "Maximum concurrent connections per WebSocket target (walker or function endpoint)."
                        },
                        "max_connections_per_user": {
                            "type": "int",
                            "default": 10,
                            "description": "Maximum concurrent WebSocket connections per authenticated user."
                        },
                        "max_anonymous_per_target": {
                            "type": "int",
                            "default": 100,
                            "description": "Maximum concurrent anonymous (unauthenticated) connections per target."
                        },
                        "target_timeout_seconds": {
                            "type": "float",
                            "default": 30,
                            "description": "Per-invocation timeout in seconds for the walker/function handling a WebSocket message."
                        },
                        "messages_per_second": {
                            "type": "float",
                            "default": 20,
                            "description": "Per-connection inbound message rate limit (token bucket refill rate)."
                        }
                    }
                },
                "events": {
                    "type": "dict",
                    "default": {},
                    "description": "Event-streaming broker configuration. Off by default. When enabled, jac-scale exposes publish() / @subscribe via the active stream (PostgresEventStream when a database URL resolves, otherwise LocalEventStream in-memory).",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable the event-streaming broker. When false, all publish() calls become no-ops."
                        },
                        "url": {
                            "type": "string",
                            "default": None,
                            "description": "Postgres connection URL for the event stream. If unset, falls back to [scale.database].url / JAC_DB_URL. With no database, LocalEventStream (in-memory) is used."
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
                            "default": "jaclang_scale",
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
