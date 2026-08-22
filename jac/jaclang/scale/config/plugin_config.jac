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
                            "default": "http://localhost:8000",
                            "description": "SSO callback host URL"
                        },
                        "client_auth_callback_url": {
                            "type": "string",
                            "default": "",
                            "description": "Client-side URL the SSO flow redirects back to after provider auth"
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
                        },
                        "apple": {
                            "type": "dict",
                            "default": {},
                            "description": "Apple OAuth configuration",
                            "nested": {
                                "client_id": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Apple OAuth client ID"
                                },
                                "client_secret": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Apple OAuth client secret"
                                }
                            }
                        },
                        "github": {
                            "type": "dict",
                            "default": {},
                            "description": "GitHub OAuth configuration",
                            "nested": {
                                "client_id": {
                                    "type": "string",
                                    "default": "",
                                    "description": "GitHub OAuth client ID"
                                },
                                "client_secret": {
                                    "type": "string",
                                    "default": "",
                                    "description": "GitHub OAuth client secret"
                                }
                            }
                        },
                        "firebase": {
                            "type": "dict",
                            "default": {},
                            "description": "Firebase auth configuration",
                            "nested": {
                                "project_id": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Firebase project id (also honored via env)"
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
                            "description": "Postgres connection URL (postgresql://user:pass@host:port/db) for this process, also honored via the JAC_DB_URL env var, which wins at runtime. Setting it here (not via the env var) also makes a deploy of this app point at that database instead of provisioning one; [scale.kubernetes] database_mode overrides that."
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
                        "database_mode": {
                            "type": "string",
                            "default": "auto",
                            "description": "What database the DEPLOYED app gets: 'provision' (a per-app Postgres owned by jac), 'external' (point it at database_url, or [scale.database] url), 'none' (wire no database at all), or 'auto' (external when a url is configured, otherwise provision). The deploying process's own JAC_DB_URL is never consulted."
                        },
                        "database_url": {
                            "type": "string",
                            "default": "",
                            "description": "Connection URL handed to the deployed app in external mode. Highest precedence, above [scale.database] url. A bare Kubernetes service name is namespace-relative: set database_namespace, or write the fully qualified <service>.<namespace>.svc.cluster.local host."
                        },
                        "database_namespace": {
                            "type": "string",
                            "default": "",
                            "description": "Namespace that runs the external database service, used to qualify a bare service name in the url when the app deploys into a different namespace. Defaults to the deploying pod's own namespace when it can be detected."
                        },
                        "postgres_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Deprecated, use database_mode. false maps to database_mode = 'none'; true is ignored because it cannot distinguish provisioning from pointing at an external database."
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
                        "revision_history_limit": {
                            "type": "int",
                            "default": 10,
                            "description": "How many superseded ReplicaSets Kubernetes keeps per Deployment, which is how far back a rollback can reach. 0 keeps no history and makes a rollback impossible."
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
                        "postgres_storage_size": {
                            "type": "string",
                            "default": "2Gi",
                            "description": "PVC size for the provisioned Postgres StatefulSet (k8s target)"
                        },
                        "cpu_request": {
                            "type": "string",
                            "default": None,
                            "description": "Container CPU request for the app pod (e.g. '100m')"
                        },
                        "cpu_limit": {
                            "type": "string",
                            "default": None,
                            "description": "Container CPU limit for the app pod (e.g. '1000m')"
                        },
                        "memory_request": {
                            "type": "string",
                            "default": None,
                            "description": "Container memory request for the app pod (e.g. '128Mi')"
                        },
                        "memory_limit": {
                            "type": "string",
                            "default": None,
                            "description": "Container memory limit for the app pod (e.g. '1Gi')"
                        },
                        "readiness_initial_delay": {
                            "type": "int",
                            "default": 10,
                            "description": "Readiness probe initialDelaySeconds"
                        },
                        "readiness_period": {
                            "type": "int",
                            "default": 20,
                            "description": "Readiness probe periodSeconds"
                        },
                        "liveness_initial_delay": {
                            "type": "int",
                            "default": 10,
                            "description": "Liveness probe initialDelaySeconds"
                        },
                        "liveness_period": {
                            "type": "int",
                            "default": 20,
                            "description": "Liveness probe periodSeconds"
                        },
                        "liveness_failure_threshold": {
                            "type": "int",
                            "default": 80,
                            "description": "Liveness probe failureThreshold"
                        },
                        "health_check_path": {
                            "type": "string",
                            "default": "/docs",
                            "description": "HTTP path used for readiness/liveness probes"
                        },
                        "python_image": {
                            "type": "string",
                            "default": "",
                            "description": "Base container image for app pods; empty resolves the default jac image"
                        },
                        "wait_image": {
                            "type": "string",
                            "default": "busybox",
                            "description": "Image used by init/wait containers"
                        },
                        "bundle_storage_class": {
                            "type": "string",
                            "default": "",
                            "description": "StorageClass for the code-bundle PVC; empty uses the cluster default"
                        },
                        "bundle_access_mode": {
                            "type": "string",
                            "default": "ReadWriteMany",
                            "description": "Access mode for the code-bundle PVC"
                        },
                        "resource_deletion_wait": {
                            "type": "int",
                            "default": 5,
                            "description": "Seconds to wait between resource deletions on destroy"
                        },
                        "aws_nlb_wait": {
                            "type": "int",
                            "default": 60,
                            "description": "Seconds to wait for an AWS NLB to become reachable"
                        },
                        "app_mount_path": {
                            "type": "string",
                            "default": "/app",
                            "description": "Mount path for the application volume inside pods"
                        },
                        "code_mount_path": {
                            "type": "string",
                            "default": "/code",
                            "description": "Mount path for the code bundle volume inside pods"
                        },
                        "workspace_path": {
                            "type": "string",
                            "default": "/code/workspace",
                            "description": "Working directory for the app inside pods"
                        },
                        "additional_packages": {
                            "type": "list",
                            "default": [],
                            "description": "Extra pip packages installed into app pods at startup"
                        },
                        "loki_enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the Loki + Alloy log pipeline (see [scale.microservices.logs])"
                        },
                        "tracing_enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the tracing stack (see [scale.microservices.tracing])"
                        },
                        "ingress_node_port": {
                            "type": "int",
                            "default": 30080,
                            "description": "NodePort used when exposing the app without a LoadBalancer"
                        },
                        "shared_ingress": {
                            "type": "bool",
                            "default": False,
                            "description": "Join a cluster-shared ingress instead of provisioning a dedicated one"
                        },
                        "shared_ingress_class": {
                            "type": "string",
                            "default": "nginx",
                            "description": "IngressClass used when shared_ingress is enabled"
                        },
                        "shared_ingress_annotations": {
                            "type": "dict",
                            "default": {},
                            "description": "Extra annotations applied to the shared ingress"
                        },
                        "shared_ingress_tls": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable TLS on the shared ingress"
                        },
                        "shared_ingress_skip_reachability": {
                            "type": "bool",
                            "default": False,
                            "description": "Skip the post-deploy reachability probe for the shared ingress"
                        },
                        "ingress_limit_rps": {
                            "type": "int",
                            "default": 20,
                            "description": "Ingress rate limit: requests per second per client"
                        },
                        "ingress_limit_burst_multiplier": {
                            "type": "int",
                            "default": 5,
                            "description": "Ingress rate limit burst multiplier"
                        },
                        "ingress_limit_connections": {
                            "type": "int",
                            "default": 20,
                            "description": "Ingress concurrent connection limit per client"
                        },
                        "ingress_session_affinity": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable cookie-based session affinity on the ingress"
                        },
                        "domain": {
                            "type": "string",
                            "default": "",
                            "description": "Public domain for the deployment (enables host-based ingress rules)"
                        },
                        "cert_manager_email": {
                            "type": "string",
                            "default": "",
                            "description": "Email used for cert-manager ACME registration when TLS is enabled"
                        },
                        "service_account_name": {
                            "type": "string",
                            "default": "",
                            "description": "ServiceAccount assigned to app pods; empty uses the namespace default"
                        },
                        "ops_console": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the experimental ops console"
                        },
                        "ops_console_mutations": {
                            "type": "bool",
                            "default": False,
                            "description": "Allow mutating operations from the ops console"
                        },
                        "kube_context": {
                            "type": "string",
                            "default": "",
                            "description": "kubectl context to deploy with; empty uses the active context"
                        },
                        "kubeconfig": {
                            "type": "string",
                            "default": "",
                            "description": "Path to an explicit kubeconfig file; empty uses the default resolution"
                        },
                        "labels": {
                            "type": "dict",
                            "default": {},
                            "description": "Extra labels applied to every generated Kubernetes resource"
                        }
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
                        "docs_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Serve the interactive API docs at /docs"
                        },
                        "suppress_health_check_logs": {
                            "type": "bool",
                            "default": False,
                            "description": "Suppress health-check endpoint access log entries (/docs, /, /openapi.json, /health, /healthz, /healthz/ready, /healthz/live) from CLI output and Kubernetes pod logs. Off by default."
                        },
                        "structured_logs": {
                            "type": "bool",
                            "default": True,
                            "description": "Install jac-scale's JSON log handler on the root logger at serving startup (the format Kubernetes pod log collection expects). Set false when embedding jac-scale in an application that owns its own logging configuration: handlers, levels and formatters are then left untouched."
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
                            "default": None,
                            "description": "Deprecated - declaring [scale.microservices.routes] is what turns microservice mode on; set false to force single-process while keeping the routes table. Absent means auto-detect (enable when routes exist). Ignored inside deployed fleet pods (the deploy already realized the topology). A future release removes this key."
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
                        "boot_health_timeout": {
                            "type": "float",
                            "default": None,
                            "description": "How long a service process may take to answer /healthz before it is given up on (seconds); absent uses the process manager default (60). Applies both when the orchestrator starts the declared services at boot and when an inter-service import spawns a peer lazily. For the lazy spawn this is a stall budget rather than a wall-clock cap: a child that is still writing to its log keeps the clock resetting, so a slow cold compile is not cut off, while a child that dies is reported immediately. Raise it for services with an expensive import graph."
                        },
                        "boot_max_wait": {
                            "type": "int",
                            "default": 90,
                            "description": "Overall window (seconds) the orchestrator waits for the whole service set to report healthy at boot before it proceeds anyway. Distinct from `boot_health_timeout`, which is per service."
                        },
                        "health_monitor_interval": {
                            "type": "float",
                            "default": None,
                            "description": "Cadence (seconds) of the background health check that restarts services which died after boot; absent uses the process manager default (10)."
                        },
                        "identity": {
                            "type": "dict",
                            "default": {},
                            "description": "Who owns user records in a fleet. The gateway serves /user/register and /user/login, so a session token it mints names a user that only the gateway's store knows; a service receiving that token has no local record for the subject.",
                            "nested": {
                                "gateway_owned": {
                                    "type": "bool",
                                    "default": True,
                                    "description": "A fleet service that receives a signature-valid, unexpired token for a user it does not know provisions that user's root once, instead of rejecting the request. Set false when a deployment manages identity itself and a service should reject unknown subjects."
                                }
                            }
                        },
                        "ingress": {
                            "type": "dict",
                            "default": {},
                            "description": "Optional K8s Ingress for the gateway. Default off (no Ingress emitted) so existing deployments don't grow one unexpectedly. HTTP only - TLS via cert-manager / ACM is deployment-specific. Routes all external traffic to gateway-service:container_port; the gateway dispatches /<svc>/* internally (member-subpath; the /api prefix was dropped).",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Emit an Ingress manifest for the gateway (opt-in)"
                                },
                                "host": {
                                    "type": "string",
                                    "default": None,
                                    "description": "Ingress host rule; omitted means match-any-host"
                                },
                                "ingress_class_name": {
                                    "type": "string",
                                    "default": None,
                                    "description": "IngressClass, e.g. 'nginx', 'alb', 'gce'"
                                },
                                "annotations": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Controller-specific annotations, e.g. nginx.ingress.kubernetes.io/proxy-body-size"
                                }
                            }
                        },
                        "routes": {
                            "type": "dict",
                            "default": {},
                            "description": "The service cut: module-name -> gateway-prefix map. Each key runs as its own service process (or pod) behind the gateway; an empty prefix derives /<module-slug>. This table is the single source of truth for which modules are services (`jac scale split <module>` adds an entry)."
                        },
                        "services": {
                            "type": "dict",
                            "default": {},
                            "description": "Per-service overrides keyed by module name. Subkeys (all optional): `file` (str, the service's entry file relative to the project root; default `<name>.jac`), `rpc_timeout` (float, default 10s, inter-service RPC calls), `http_forward_timeout` (float, default 30s, gateway-to-service forward), `replicas` (int, default 1, K8s Deployment.spec.replicas), `cpu_request` / `cpu_limit` (str, e.g. \"100m\", K8s container resources), `memory_request` / `memory_limit` (str, e.g. \"128Mi\"), `env` (dict[str,str], extra container env vars merged with auto-set JAC_SV_NAME), and nested `hpa` / `pdb` sub-tables. `hpa` keys: `enabled` (bool, default true), `min` (int, default 1), `max` (int, default 3), `cpu_target` (int percent, default 50), `memory_target` (int percent of memory request, default 80), `behavior` (table, default `{}`): a raw HPA `behavior` fragment (`scaleUp`/`scaleDown`, each with `stabilizationWindowSeconds`/`policies`/`selectPolicy`) deep-merged over the generated scale-rate defaults - same merge semantics as `deployment_overlay` (maps merge recursively, the `policies` list has no `name` key so it replaces wholesale rather than merging by entry); applies to both \"hpa\" and \"keda\" engines since both route through the same `Autoscaler._build_behavior` (for keda it only governs scaling above zero replicas - the drop to zero remains controlled by `autoscaler_cooldown`, the ScaledObject's cooldownPeriod). Use it to slow scale-down for connection-heavy services (e.g. `[services.NAME.hpa.behavior.scaleDown] stabilizationWindowSeconds = 600, selectPolicy = 'Min', policies = [{ type = 'Pods', value = 2, periodSeconds = 300 }]`) without imposing the same rate limit on every service via the app-global `autoscaler_cooldown`. `pdb` keys: `enabled` (bool, default true), `max_unavailable` (int, default 1; no PDB is emitted when it is at or above the service's replica floor, since such a budget permits evicting every replica), `min_available` (int, default unset; wins over `max_unavailable` and is the only way to ask for a budget that holds at one replica). `deployment_overlay` (table): a raw Deployment-manifest fragment merged into the generated manifest at build time - maps merge recursively, lists whose members all carry `name` (containers, volumes, env, initContainers, volumeMounts) merge by that name, anything else replaces; identity fields (metadata.name/namespace, selector, the app/managed template labels) are reasserted after the merge. The main container's `name` is the k8s-safe service name (e.g. `builder-sv`; gateway is `gateway`). Use it for nodeSelector, probe tuning, extra volumes/env/init containers - anything the schema has no first-class key for - so pods are right on the FIRST rollout instead of being kubectl-patched into a second one. Overlays add and override only: there is no delete directive (setting a key to null stores null rather than removing the generated field). Gateway uses the `__gateway__` key. `[[services.NAME.triggers]]` array (KEDA only): per-service event-driven triggers; each entry has `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). Requires `autoscaler_engine = \"keda\"` in [scale.kubernetes]. Example: [scale.microservices.services.llm_app] rpc_timeout = 120.0, replicas = 2, cpu_limit = \"2000m\", memory_limit = \"4Gi\", env = { LOG_LEVEL = \"DEBUG\" }, [scale.microservices.services.llm_app.hpa] max = 20, cpu_target = 60",
                            "nested_each": {
                                "file": {
                                    "type": "string",
                                    "default": None,
                                    "description": "Service entry file relative to the project root; default <name>.jac"
                                },
                                "rpc_timeout": {
                                    "type": "float",
                                    "default": 10.0,
                                    "description": "Inter-service RPC call timeout in seconds"
                                },
                                "http_forward_timeout": {
                                    "type": "float",
                                    "default": 30.0,
                                    "description": "Gateway-to-service forward timeout in seconds"
                                },
                                "replicas": {
                                    "type": "int",
                                    "default": 1,
                                    "description": "K8s Deployment.spec.replicas"
                                },
                                "cpu_request": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container CPU request, e.g. '100m'"
                                },
                                "cpu_limit": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container CPU limit, e.g. '2000m'"
                                },
                                "memory_request": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container memory request, e.g. '128Mi'"
                                },
                                "memory_limit": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container memory limit, e.g. '4Gi'"
                                },
                                "env": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Extra container env vars merged with auto-set JAC_SV_NAME"
                                },
                                "hpa": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Per-service autoscaler settings",
                                    "nested": {
                                        "enabled": {
                                            "type": "bool",
                                            "default": True,
                                            "description": "Emit an HPA/ScaledObject for this service"
                                        },
                                        "min": {
                                            "type": "int",
                                            "default": 1,
                                            "description": "Minimum replicas"
                                        },
                                        "max": {
                                            "type": "int",
                                            "default": 3,
                                            "description": "Maximum replicas"
                                        },
                                        "cpu_target": {
                                            "type": "int",
                                            "default": 50,
                                            "description": "CPU utilization target percent"
                                        },
                                        "memory_target": {
                                            "type": "int",
                                            "default": 80,
                                            "description": "Memory utilization target percent (of the memory request)"
                                        },
                                        "behavior": {
                                            "type": "dict",
                                            "default": {},
                                            "description": "Raw HPA behavior fragment deep-merged over generated defaults"
                                        }
                                    }
                                },
                                "pdb": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Per-service PodDisruptionBudget settings",
                                    "nested": {
                                        "enabled": {
                                            "type": "bool",
                                            "default": True,
                                            "description": "Emit a PDB for this service"
                                        },
                                        "max_unavailable": {
                                            "type": "int",
                                            "default": 1,
                                            "description": "PDB maxUnavailable. A budget that permits evicting every replica protects nothing, so no PDB is emitted when this is at or above the service's replica floor (hpa.min, or replicas when the HPA is off)."
                                        },
                                        "min_available": {
                                            "type": "int",
                                            "default": None,
                                            "description": "PDB minAvailable. Set it to keep a floor of healthy pods through voluntary disruption; it wins over max_unavailable. min_available = 1 on a single-replica service refuses node drains until the service is scaled up, which is the trade for never going to zero."
                                        }
                                    }
                                },
                                "deployment_overlay": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Raw Deployment-manifest fragment merged into the generated manifest"
                                },
                                "triggers": {
                                    "type": "list",
                                    "default": [],
                                    "description": "(KEDA only) Per-service event-driven trigger dicts"
                                }
                            }
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
                                },
                                "static_mounts": {
                                    "type": "list",
                                    "default": [],
                                    "description": "Extra static directories served by the gateway; array of tables, each with `url_prefix` and `local_path`"
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
                        },
                        "tracing": {
                            "type": "dict",
                            "default": {},
                            "description": "Distributed tracing for gateway and services. Off by default.",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Enable trace emission"
                                },
                                "endpoint": {
                                    "type": "string",
                                    "default": None,
                                    "description": "Collector endpoint traces are shipped to"
                                },
                                "sample_ratio": {
                                    "type": "float",
                                    "default": 1.0,
                                    "description": "Fraction of requests to trace (0.0-1.0)"
                                }
                            }
                        },
                        "service_files": {
                            "type": "dict",
                            "default": {},
                            "description": "Module-name -> entry-file map for services whose file differs from <name>.jac; normally maintained by the deploy pipeline rather than by hand"
                        },
                        "shared_volumes": {
                            "type": "list",
                            "default": [],
                            "description": "Volume declarations mounted into every service pod"
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
                        },
                        "k8s_metrics_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Deploy the Kubernetes monitoring stack (Prometheus + Grafana) alongside the app"
                        }
                    }
                },
                "webhook": {
                    "type": "dict",
                    "default": {},
                    "description": "Inbound webhook verification and limits",
                    "nested": {
                        "secret": {
                            "type": "string",
                            "default": "webhook-secret-key",
                            "description": "Shared secret used to verify webhook signatures"
                        },
                        "signature_header": {
                            "type": "string",
                            "default": "X-Webhook-Signature",
                            "description": "Header carrying the webhook signature"
                        },
                        "timestamp_header": {
                            "type": "string",
                            "default": "X-Webhook-Timestamp",
                            "description": "Header carrying the webhook timestamp"
                        },
                        "verify_signature": {
                            "type": "bool",
                            "default": True,
                            "description": "Reject webhooks whose signature does not verify"
                        },
                        "replay_tolerance_seconds": {
                            "type": "int",
                            "default": 300,
                            "description": "Maximum allowed clock skew before a webhook is treated as a replay"
                        },
                        "max_body_bytes": {
                            "type": "int",
                            "default": 1048576,
                            "description": "Maximum webhook body size in bytes"
                        },
                        "rate_limit_per_minute": {
                            "type": "int",
                            "default": 0,
                            "description": "Webhook rate limit per minute; 0 disables"
                        },
                        "api_key_expiry_days": {
                            "type": "int",
                            "default": 365,
                            "description": "Lifetime of generated webhook API keys in days"
                        }
                    }
                },
                "admin": {
                    "type": "dict",
                    "default": {},
                    "description": "Bootstrap admin account configuration",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Create the bootstrap admin user on first start"
                        },
                        "username": {
                            "type": "string",
                            "default": "admin",
                            "description": "Admin username"
                        },
                        "email": {
                            "type": "string",
                            "default": "admin@localhost",
                            "description": "Admin email address"
                        },
                        "default_password": {
                            "type": "string",
                            "default": "changeme",
                            "description": "Initial admin password; must be rotated on first login by default"
                        },
                        "session_expiry_hours": {
                            "type": "int",
                            "default": 24,
                            "description": "Admin session lifetime in hours"
                        },
                        "require_password_reset": {
                            "type": "bool",
                            "default": True,
                            "description": "Force a password change on first admin login"
                        }
                    }
                },
                "scheduler": {
                    "type": "dict",
                    "default": {},
                    "description": "Scheduled-job runner configuration",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": None,
                            "description": "Declares scheduler use; read at install time for capability detection"
                        },
                        "collection": {
                            "type": "string",
                            "default": "scheduled_jobs",
                            "description": "Collection name where job state is persisted"
                        },
                        "thread_pool_size": {
                            "type": "int",
                            "default": 10,
                            "description": "Worker threads available to the scheduler"
                        },
                        "misfire_grace_time": {
                            "type": "int",
                            "default": 60,
                            "description": "Seconds a job may fire late before it is skipped"
                        },
                        "shutdown_timeout": {
                            "type": "int",
                            "default": 10,
                            "description": "Seconds to wait for running jobs on shutdown"
                        },
                        "system_user_password": {
                            "type": "string",
                            "default": "__no_login__",
                            "description": "Password for the internal scheduler system user"
                        },
                        "user_exists_ttl": {
                            "type": "float",
                            "default": 30.0,
                            "description": "Seconds the scheduler caches user-existence checks"
                        }
                    }
                },
                "telemetry": {
                    "type": "dict",
                    "default": {},
                    "description": "In-process telemetry buffer configuration",
                    "nested": {
                        "max_traces": {
                            "type": "int",
                            "default": 1000,
                            "description": "Maximum traces retained in memory"
                        }
                    }
                },
                "emailer": {
                    "type": "dict",
                    "default": {},
                    "description": "Outbound email (password reset, verification) configuration",
                    "nested": {
                        "provider": {
                            "type": "string",
                            "default": "",
                            "description": "Emailer provider: empty disables email; 'smtp' or a custom 'module.path:ClassName' enables it"
                        },
                        "enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable outbound email"
                        },
                        "from_address": {
                            "type": "string",
                            "default": "",
                            "description": "From address on outbound mail"
                        },
                        "smtp": {
                            "type": "dict",
                            "default": {},
                            "description": "SMTP transport settings",
                            "nested": {
                                "host": {
                                    "type": "string",
                                    "default": "localhost",
                                    "description": "SMTP server host"
                                },
                                "port": {
                                    "type": "int",
                                    "default": 25,
                                    "description": "SMTP server port"
                                },
                                "username": {
                                    "type": "string",
                                    "default": "",
                                    "description": "SMTP username"
                                },
                                "password": {
                                    "type": "string",
                                    "default": "",
                                    "description": "SMTP password (EMAILER_SMTP_PASSWORD env overrides)"
                                },
                                "use_tls": {
                                    "type": "bool",
                                    "default": True,
                                    "description": "Use STARTTLS"
                                },
                                "timeout": {
                                    "type": "float",
                                    "default": 10.0,
                                    "description": "SMTP connection timeout in seconds"
                                }
                            }
                        }
                    }
                },
                "auth": {
                    "type": "dict",
                    "default": {},
                    "description": "Password-auth token and rate-limit configuration",
                    "nested": {
                        "reset_token_ttl_seconds": {
                            "type": "int",
                            "default": 1800,
                            "description": "Password-reset token lifetime in seconds"
                        },
                        "verify_token_ttl_seconds": {
                            "type": "int",
                            "default": 86400,
                            "description": "Email-verification token lifetime in seconds"
                        },
                        "reset_url_template": {
                            "type": "string",
                            "default": "",
                            "description": "URL template embedded in password-reset emails"
                        },
                        "verify_url_template": {
                            "type": "string",
                            "default": "",
                            "description": "URL template embedded in verification emails"
                        },
                        "token_collection": {
                            "type": "string",
                            "default": "auth_tokens",
                            "description": "Collection name where auth tokens are persisted"
                        },
                        "password_hash_cost": {
                            "type": "int",
                            "default": 14,
                            "description": "bcrypt cost factor, clamped to 10..17 (JAC_SCALE_PASSWORD_HASH_COST env overrides)"
                        },
                        "forgot_password_rate_per_hour": {
                            "type": "int",
                            "default": 3,
                            "description": "Forgot-password requests allowed per hour per account"
                        },
                        "forgot_password_burst": {
                            "type": "int",
                            "default": 3,
                            "description": "Forgot-password burst allowance"
                        },
                        "send_verification_rate_per_hour": {
                            "type": "int",
                            "default": 5,
                            "description": "Verification emails allowed per hour per account"
                        },
                        "send_verification_burst": {
                            "type": "int",
                            "default": 5,
                            "description": "Verification email burst allowance"
                        }
                    }
                },
                "storage": {
                    "type": "dict",
                    "default": {},
                    "description": "Persistence storage backend configuration (e.g. backend, type); read at install time for capability detection. Keys are backend-specific and not validated."
                },
                "deploy": {
                    "type": "dict",
                    "default": {},
                    "description": "Deploy intent (e.g. target = 'kubernetes'); read at install time for capability detection. Keys are target-specific and not validated."
                },
                "tracing": {
                    "type": "dict",
                    "default": {},
                    "description": "Tracing intent (enabled = true installs the tracing extras at install time); runtime tracing settings live under [scale.microservices.tracing]."
                },
                "fat_bundle": {
                    "type": "bool",
                    "default": None,
                    "description": "Bundle all dependencies into the deploy artifact; absent lets the deploy pipeline decide"
                },
                "seal_timeout": {
                    "type": "int",
                    "default": None,
                    "description": "Seconds to wait for the code bundle to seal before deploy fails"
                }
            }
        };
    }
}
