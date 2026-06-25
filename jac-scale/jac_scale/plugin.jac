"""File covering plugin implementation."""
import os;
import pathlib;
import from dotenv { load_dotenv }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, CommandPriority, HookContext }
import from jaclang.cli.console { console }
import from jaclang.jac0core.runtime { hookimpl, plugin_manager }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.server { JacAPIServer as JacServer }
import from .context { JScaleExecutionContext }
import from .serve { JacAPIServer }
import from .jserver.jfast_api { JFastApiServer }
import from .config_loader { get_scale_config }
import from .deploy.target.factory { DeploymentTargetFactory }
import from .observability.factory { UtilityFactory }
import from .config.app_config { AppConfig }
import from .user_manager { JacScaleUserManager }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.storage { Storage }

"""Print the zero-config auto-detect info line on local microservice startup."""
def _print_autodetect_banner(routes: dict[str, str]) {
    names = sorted(routes.keys());
    plural = "s" if len(names) != 1 else "";
    console.print(
        f"Microservice mode (auto-detected): {len(names)} service{plural} "
        f"[{', '.join(names)}], running locally as subprocesses with no "
        f"Docker images.",
        style="cyan"
    );
    pairs = ", ".join([f"{n} -> {routes[n]}" for n in names]);
    console.print(f"  Default routes: {pairs}", style="muted");
    console.print(
        "  Routes are auto-derived; set [plugins.scale.microservices] in jac.toml to customize.",
        style="muted"
    );
}

"""Pre-hook for jac start command to handle microservice mode and --scale flag."""
def _scale_pre_hook(context: HookContext) -> None {
    # Microservice mode: services are spawned on-demand by core's BFS
    # discovery + our ensure_sv_service hookimpl. The pre-hook only
    # bootstraps the gateway for client-facing routing when enabled
    # and we're NOT already running as an sv sibling child.
    scale_config = get_scale_config();
    ms_config = scale_config.get_microservices_config();
    is_sv_sibling = os.environ.get("JAC_SV_SIBLING") == "1";
    scale_flag = context.get_arg("scale", False);

    # LOCAL microservice mode gate. `enabled` is tri-state:
    #   True  -> explicit opt-in (config wins; routes auto-filled if absent)
    #   False -> explicit opt-out (always stay a monolith)
    #   None  -> unset: auto-detect from `sv import` / `to sv:` source markers
    # Children (JAC_SV_SIBLING=1) never enter (re-orchestration would fork
    # infinitely); --scale is the remote deploy path handled below.
    enabled = ms_config.get("enabled", None);
    if (not is_sv_sibling) and (not scale_flag) and (enabled is not False) {
        filename = context.get_arg("filename");
        # Discover when unset (to decide whether to enter) or when enabled
        # but no routes were declared (to fill defaults). Explicit routes win.
        if filename and ((enabled is None) or (not ms_config.get("routes", {}))) {
            import from jac_scale.runtime.discovery.discovery { discover_sv_services }
            if not ms_config.get("routes", {}) {
                ms_config["routes"] = discover_sv_services(filename);
            }
        }
        # The LocalRealizer owns the decide-and-dispatch (via the planner): it
        # serves a microservice fleet or declines so core serves the monolith.
        import from jac_scale.runtime.realizer.local_realizer { LocalRealizer }
        realizer = LocalRealizer(ms_config=ms_config);
        if realizer.should_serve(enabled) {
            if enabled is None {
                _print_autodetect_banner(ms_config.get("routes", {}));
            }
            realizer.serve();
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 0);
            return;
        }
    }

    # --scale: the KubernetesRealizer owns target selection, config, dry-run,
    # TLS, and the deploy, setting the hook's cancel/return data.
    if scale_flag {
        import from jac_scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
        KubernetesRealizer(ms_config=ms_config).realize(context);
    }
}

"""Print deployment status as a formatted table."""
def _print_deployment_status(status_data: dict) -> None {
    app_name = status_data.get('app_name', 'unknown');
    namespace = status_data.get('namespace', 'default');
    components = status_data.get('components', []);
    urls = status_data.get('urls', {});
    error = status_data.get('error');

    console.print();
    console.print("  Jac Scale - Deployment Status", style="bold cyan");
    console.print(f"  App: {app_name}   Namespace: {namespace}", style="bold");
    console.print();

    if error {
        console.error(f"Cannot connect to cluster: {error}", emoji=False);
        console.print();
        return;
    }

    status_display = {
        'running': '● Running',
        'degraded': '◑ Degraded',
        'pending': '⟳ Pending',
        'restarting': '↺ Restarting',
        'failed': '✗ Failed',
        'not_deployed': '○ Not Deployed',
        'unknown': '? Unknown',

    };
    status_style = {
        'running': 'bold green',
        'degraded': 'bold yellow',
        'pending': 'bold yellow',
        'restarting': 'bold red',
        'failed': 'bold red',
        'not_deployed': 'muted',
        'unknown': 'muted',

    };

    console.print(
        f"  {'Component':18s}  {'Status':22s}  {'Pods':>6s}", style="bold dim"
    );
    for comp in components {
        s = comp.get('status', 'unknown');
        ready = comp.get('ready', 0);
        total = comp.get('total', 0);
        label = status_display.get(s, s);
        if s in ['not_deployed', 'unknown'] {
            pods_str = '-';
        } else {
            pods_str = f"{ready}/{total}";
        }
        console.print(
            f"  {comp.get('name', ''):18s}  {label:22s}  {pods_str:>6s}",
            style=status_style.get(s, 'muted')
        );
    }

    if urls {
        console.print("  Service URLs", style="bold");
        console.print(f"  {'─' * 48}", style="muted");
        if 'app' in urls {
            console.print(f"  Application:   {urls['app']}", style="bold");
        }
        if 'grafana' in urls {
            console.print(f"  Grafana:       {urls['grafana']}", style="bold");
        }
        if 'redis_insight' in urls {
            console.print(f"  RedisInsight:  {urls['redis_insight']}", style="bold");
        }
        if 'mongo_express' in urls {
            console.print(f"  Mongo Express: {urls['mongo_express']}", style="bold");
        }
        console.print();
    }
}

"""Jac CLI."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd {
        """Jac Scale functionality.""";
        registry = get_registry();

        # Extend jac start with --scale and related flags
        registry.extend_command(
            "start",
            args=[
                Arg.create(
                    "scale",
                    typ=bool,
                    default=False,
                    help="Deploy to a target platform instead of running locally",
                    short=""  # Disable auto-generated -s (conflicts with --session)
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),
                Arg.create(
                    "enable-tls",
                    typ=bool,
                    default=False,
                    help="Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB)",
                    short=""
                ),
                Arg.create(
                    "dry-run",
                    typ=bool,
                    default=False,
                    help="Print manifests + image plan that would be applied; touch nothing (no cluster contact, no build, no DB provisioning)",
                    short=""
                ),
                Arg.create(
                    "show-yaml",
                    typ=bool,
                    default=False,
                    help="With --dry-run: also dump the raw multi-doc YAML stream (for `kubectl diff` or similar). Off by default; the card view above is the friendly summary",
                    short=""
                ),
                Arg.create(
                    "experimental",
                    typ=bool,
                    default=False,
                    help="Build the pod's `jac` binary from a cloned jaseci checkout (the branch's own jaclang) instead of the released installer",
                    short=""
                ),
            ],
            pre_hook=_scale_pre_hook,
            source="jac-scale"
        );

        @registry.command(
            name="destroy",
            help="Remove deployment from target platform",
            args=[
                Arg.create(
                    "file_path", kind=ArgKind.POSITIONAL, help="Path to .jac file"
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),
                Arg.create(
                    "component",
                    typ=str,
                    default="",
                    help="Component to destroy (default: entire deployment). Choices: application, database, cache, monitoring, dashboard",
                ),

            ],
            examples=[
                ("jac destroy app.jac", "Remove entire deployment for app"),
                (
                    "jac destroy app.jac --component application",
                    "Remove only the application"
                ),
                ("jac destroy app.jac --component database", "Remove only MongoDB"),
                ("jac destroy app.jac --component cache", "Remove only Redis"),
                (
                    "jac destroy app.jac --component monitoring",
                    "Remove only monitoring stack"
                ),
                (
                    "jac destroy app.jac --component dashboard",
                    "Remove only dashboards (Mongo Express + RedisInsight)"
                ),

            ],
            group="deployment",
            priority=CommandPriority.PLUGIN,
            source="jac-scale"
        )
        def destroy(
            file_path: str, target: str = "kubernetes", component: str = ""
        ) -> int {
            if not os.path.exists(file_path) {
                raise FileNotFoundError(f"File not found: '{file_path}'");
            }

            valid_components = [
                "application",
                "database",
                "cache",
                "monitoring",
                "dashboard"
            ];
            if component and target != 'kubernetes' {
                console.print(
                    "ERROR: --component is only supported for the 'kubernetes' target.",
                    style="error"
                );
                return 1;
            }
            if component and component not in valid_components {
                console.print(
                    f"ERROR: Invalid component '{component}'. Valid choices: {', '.join(
                        valid_components
                    )}",
                    style="error"
                );
                return 1;
            }

            code_folder = os.path.dirname(file_path) or '.';
            dotenv_path = os.path.join(code_folder, '.env');
            load_dotenv(dotenv_path);

            # Get configuration
            scale_config = get_scale_config();

            # Create logger
            logger = UtilityFactory.create_logger('standard');

            # Same target-specific config dispatch as the deploy path.
            if target in ('kubernetes', 'kubernetes-microservice') {
                target_config = scale_config.get_kubernetes_config();
            } else {
                # Custom targets load config from [plugins.scale.<target>]
                target_config = scale_config.get_section(target);
            }

            app_name = target_config.get('app_name', 'jaseci');
            namespace = target_config.get('namespace', 'default');

            # Warn user and require confirmation before proceeding
            if component {
                console.print(
                    f"WARNING: You are about to delete component '{component}' from deployment '{app_name}'.",
                    style="bold red"
                );
            } else {
                console.print(
                    f"WARNING: You are about to delete namespace '{namespace}' and all its associated resources.",
                    style="bold red"
                );
            }
            confirmation = input(
                "Are you sure you want to proceed? (y/n): "
            ).strip().lower();
            if confirmation != 'y' {
                console.print("Destroy cancelled.");
                return 1;
            }

            # Create deployment target and destroy
            deployment_target = DeploymentTargetFactory.create(
                target, target_config, logger
            );
            deployment_target.destroy(app_name, component);

            if component {
                console.print(
                    f"Successfully destroyed component '{component}' from '{app_name}'"
                );
            } else {
                console.print(
                    f"Successfully destroyed deployment '{app_name}' from {target}"
                );
            }
            return 0;
        }

        @registry.command(
            name="status",
            help="Show deployment status of jaseci application on target platform",
            args=[
                Arg.create(
                    "file_path", kind=ArgKind.POSITIONAL, help="Path to .jac file"
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),

            ],
            examples=[("jac status app.jac", "Show deployment status of app"), ],
            group="deployment",
            priority=CommandPriority.PLUGIN,
            source="jac-scale"
        )
        def status(file_path: str, target: str = "kubernetes") -> int {
            if not os.path.exists(file_path) {
                raise FileNotFoundError(f"File not found: '{file_path}'");
            }
            code_folder = os.path.dirname(file_path) or '.';
            dotenv_path = os.path.join(code_folder, '.env');
            load_dotenv(dotenv_path);

            # Get configuration
            scale_config = get_scale_config();

            # Create logger
            logger = UtilityFactory.create_logger('standard');

            # Get target-specific config
            if target == 'kubernetes' {
                target_config = scale_config.get_kubernetes_config();
            } else {
                # Custom targets load config from [plugins.scale.<target>]
                target_config = scale_config.get_section(target);
            }

            # Create deployment target
            deployment_target = DeploymentTargetFactory.create(
                target, target_config, logger
            );
            app_name = target_config.get('app_name', 'jaseci');

            # Get and display status
            status_data = deployment_target.get_full_status(app_name);
            _print_deployment_status(status_data);
            return 0;
        }

        @registry.command(
            name="scale",
            help="Manage microservice deployments - status, stop, restart, logs",
            args=[
                Arg.create(
                    "action",
                    kind=ArgKind.POSITIONAL,
                    help="Action: status, stop, restart, logs, destroy"
                ),
                Arg.create(
                    "service_name",
                    kind=ArgKind.POSITIONAL,
                    default="",
                    help="Service name (required for stop, restart, logs)"
                ),
                Arg.create(
                    "lines",
                    typ=int,
                    default=50,
                    help="Number of log lines to show (for 'logs' action)"
                ),

            ],
            examples=[
                ("jac scale status", "Show status of all microservices"),
                ("jac scale stop orders", "Stop the orders service"),
                ("jac scale restart cart", "Restart the cart service"),
                ("jac scale logs products", "Show logs for products service"),
                ("jac scale destroy", "Stop all services"),

            ],
            group="microservices",
            priority=CommandPriority.PLUGIN,
            source="jac-scale"
        )
        def scale_cmd(action: str, service_name: str = "", lines: int = 50) -> int {
            import from jac_scale.runtime.orchestrator.orchestrator {
                build_registry
            }
            import from jac_scale.runtime.orchestrator.local_deployer { LocalDeployer }

            scale_config = get_scale_config();
            ms_config = scale_config.get_microservices_config();

            # Mirror _scale_pre_hook's tri-state semantics so these management
            # commands work in zero-config auto-detect mode too. Only an
            # explicit `enabled = false` is an opt-out; unset (None) and true
            # both proceed.
            if ms_config.get("enabled", None) is False {
                console.print(
                    "Microservice mode is disabled (enabled = false in jac.toml).",
                    style="error"
                );
                return 1;
            }

            # Fill routes from auto-discovery (scanning the working directory)
            # when none are declared, matching what `jac start` does on launch.
            if not ms_config.get("routes", {}) {
                import from jac_scale.runtime.discovery.discovery { discover_sv_services }
                discovered = discover_sv_services(".");
                if discovered {
                    ms_config["routes"] = discovered;
                } else {
                    console.print(
                        "No microservices found: no routes in "
                        "[plugins.scale.microservices.routes] and no "
                        "`sv import` / `to sv:` services detected in the "
                        "current directory.",
                        style="error"
                    );
                    return 1;
                }
            }

            registry = build_registry(ms_config);
            deployer = LocalDeployer(registry=registry, target="local");

            if action == "status" {
                svc_status = deployer.status();
                console.print();
                console.print("  Microservice Status", style="bold cyan");
                console.print();
                for (name, info) in svc_status.items() {
                    status_str = info.get("status", "unknown");
                    running = info.get("running", False);
                    port = info.get("port", 0);
                    pid = info.get("pid");
                    prefix = info.get("prefix", "");
                    if running {
                        console.print(
                            f"  ● {name:12s} {prefix:20s} port={port} pid={pid}",
                            style="success"
                        );
                    } else {
                        console.print(
                            f"  ○ {name:12s} {prefix:20s} (not running)", style="error"
                        );
                    }
                }
                console.print();
            } elif action == "stop" {
                if not service_name {
                    console.print(
                        "Service name required: jac scale stop <name>", style="error"
                    );
                    return 1;
                }
                if deployer.stop_service(service_name) {
                    console.success(f"Stopped {service_name}", emoji=False);
                } else {
                    console.error(f"Failed to stop {service_name}", emoji=False);
                    return 1;
                }
            } elif action == "restart" {
                if not service_name {
                    console.print(
                        "Service name required: jac scale restart <name>", style="error"
                    );
                    return 1;
                }
                if deployer.restart_service(service_name) {
                    console.success(f"Restarted {service_name}", emoji=False);
                } else {
                    console.error(f"Failed to restart {service_name}", emoji=False);
                    return 1;
                }
            } elif action == "logs" {
                if not service_name {
                    console.print(
                        "Service name required: jac scale logs <name>", style="error"
                    );
                    return 1;
                }
                log_output = deployer.get_logs(service_name, lines);
                console.print(log_output);
            } elif action == "destroy" {
                deployer.destroy_all();
                console.success("All services stopped", emoji=False);
            } elif action == "gateway" {
                # K8s gateway-only mode: no local service spawning, peer
                # resolution via DNS through get_sv_registry.
                import from jac_scale.runtime.orchestrator.orchestrator {
                    start_gateway_only
                }
                start_gateway_only(ms_config);
                return 0;
            } else {
                console.error(f"Unknown action: '{action}'", emoji=False);
                console.print("Actions: status, stop, restart, logs, destroy, gateway");
                return 1;
            }

            return 0;
        }
    }
}

"""Jac Scale Plugin Implementation."""
class JacScalePlugin {
    @hookimpl
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext {
        # Storage backend configured via environment (MONGODB_URI, etc.) -
        # base_path_dir / full_target_path are SQLite-backend artifacts that
        # don't apply here, but the spec carries them so we accept the kwargs.
        ctx = JScaleExecutionContext();
        if user_root is not None {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    """Create the API server instance.

    Note: jac-scale doesn't bind the port until run_server is called.
    Port fallback is handled in run_server.
    """
    @hookimpl
    static def create_server(
        jac_server: JacServer, host: str, port: int
    ) -> JFastApiServer {
        return JFastApiServer([]);
    }

    """Provide jac-scale's enhanced JacAPIServer class."""
    @hookimpl
    static def get_api_server_class -> type {
        return JacAPIServer;
    }

    """Provide jac-scale's UserManager."""
    @hookimpl
    static def get_user_manager(base_path: str) -> UserManager {
        return JacScaleUserManager(base_path=base_path);
    }

    """Provide jac-scale's storage backend.

    This overrides the core store() to use jac-scale's StorageFactory,
    which supports cloud backends (S3, GCS, Azure) via configuration.
    """
    @hookimpl
    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        import from .storage.factory { StorageFactory }
        return StorageFactory.get_default(base_path, create_dirs);
    }

    """Spawn a sibling sv-service as a subprocess via LocalDeployer.

    Overrides core's default (which spawns an in-process thread). We spawn
    as a subprocess so each service has its own ModuleIntrospector, graph,
    and lifecycle - matching K8s pod semantics in production.

    Called by sv_client._ensure_available when a consumer does
    sv import from X and X is not yet registered.
    """
    @hookimpl
    static def ensure_sv_service(module_name: str, base_path: str) -> None {
        import os;
        import atexit;
        import subprocess;
        import from jaclang.runtimelib { sv_client }
        import from pathlib { Path }
        import from jac_scale.runtime.context.util {
            pick_free_port,
            resolve_jac_binary,
            wait_for_health
        }

        # Idempotent: skip if already registered
        if module_name in sv_client._registry {
            return;
        }
        if module_name in sv_client._test_clients {
            return;
        }

        # K8s mode: register peer's DNS URL instead of spawning a
        # subprocess (K8s controller owns peer pods). Detected via
        # KUBERNETES_SERVICE_HOST. Falls through to local spawn on
        # config-read failure so the local path stays unaffected.
        if "KUBERNETES_SERVICE_HOST" in os.environ {
            try {
                import from jac_scale.config_loader { get_scale_config }
                import from jac_scale.deploy.target.kubernetes.microservice.manifest_builder {
                    k8s_safe_name
                }
                import from jac_scale.runtime.context.util {
                    k8s_service_dns_url,
                    in_cluster_namespace
                }
                ms_cfg = get_scale_config().get_microservices_config();
                port: int = int(ms_cfg.get("gateway_port", 8000));
                dns_url = k8s_service_dns_url(
                    k8s_safe_name(module_name), in_cluster_namespace(), port
                );
                sv_client.register(module_name, dns_url);
                return;
            } except Exception {
                # Defensive: fall through to local-mode spawn on config
                # error so we don't hard-fail on a transient issue.
                ;
            }
        }

        base_dir = Path(base_path);
        module_file = base_dir / f"{module_name}.jac";
        if not module_file.exists() {
            raise RuntimeError(
                f"sv-to-sv service '{module_name}': file not found at {module_file}"
            );
        }

        port: int = pick_free_port(module_name);
        base_url: str = f"http://127.0.0.1:{port}";

        # JAC_SV_SIBLING prevents the child's _scale_pre_hook from re-entering
        # microservice orchestration (it would try to spawn peers again).
        child_env = dict(os.environ);
        child_env["JAC_SV_SIBLING"] = "1";

        cmd = [
            resolve_jac_binary(),
            "start",
            str(module_file),
            "--port",
            str(port),
            "--no_client"
        ];

        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=child_env,
            cwd=str(base_dir)
        );

        if not wait_for_health(base_url, lambda : proc.poll() is None) {
            proc.terminate();
            raise RuntimeError(
                f"sv-to-sv service '{module_name}' did not become healthy at {base_url}"
            );
        }

        sv_client.register(module_name, base_url);

        def _cleanup {
            if proc.poll() is None {
                proc.terminate();
            }
        }
        atexit.register(_cleanup);
    }

    """Override core's get_sv_registry to return DNS-based URLs in K8s.

    Detects K8s-in-cluster via the `KUBERNETES_SERVICE_HOST` env var
    (set in every pod by K8s automatically). When set, builds a DNS map
    `{module_name: http://{name}-service.{namespace}.svc.cluster.local:{port}}`
    from the configured routes table. When NOT set, falls back to core's
    default behavior (`dict(sv_client._registry)`), which has localhost
    URLs from local-mode subprocess spawning.

    This is the single swap point that makes the gateway work unchanged
    in both local and K8s modes - `gateway.resolve_target_url` calls
    `JacRuntime.get_sv_registry()`, plugin precedence picks this impl,
    DNS resolution does the rest.
    """
    @hookimpl
    static def get_sv_registry -> dict[str, str] {
        import os;
        import from jaclang.runtimelib { sv_client }

        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            # Local mode (or any non-K8s runtime): use the default.
            return dict(sv_client._registry);
        }

        # K8s mode: build DNS map from configured routes.
        try {
            import from jac_scale.config_loader { get_scale_config }
            import from jac_scale.deploy.target.kubernetes.microservice.runtime_resolver {
                build_k8s_registry
            }
            ms_cfg = get_scale_config().get_microservices_config();
            routes: dict[str, str] = ms_cfg.get("routes", {});
            port: int = int(ms_cfg.get("gateway_port", 8000));
            return build_k8s_registry(routes, port);
        } except Exception as e {
            # Defensive: fall back to default on config-read failure.
            import logging;
            logging.getLogger(__name__).warning(
                f"K8s get_sv_registry fell back to local registry: {e}"
            );
            return dict(sv_client._registry);
        }
    }

    """Override core's sv_service_call with auth forwarding + retry + circuit breaker.

    Reads the auth token from _auth_ctx (set by the FastAPI middleware in
    jfast_api.impl.jac at the start of each inbound request) and attaches
    it to the outgoing httpx.post.

    Retries transport-level failures (connect errors, timeouts) with
    exponential backoff: 0.1s, 0.2s, 0.4s (3 attempts total). Does NOT
    retry on successful HTTP responses that carry application errors in
    the envelope (ok=false) - those are deterministic and a retry won't
    change them. 4xx/5xx HTTP statuses surface as envelope errors in
    jac-scale's server, so they also don't retry.

    Per-provider circuit breaker wraps the retry loop. After
    _BREAKER_TRIP_THRESHOLD consecutive transport-failure cycles the
    breaker opens and subsequent calls fail fast (no httpx.post) until
    _BREAKER_COOLDOWN_SECONDS elapses; the first call after cooldown
    becomes a probe that either closes the breaker on success or
    re-opens it on failure.

    In K8s, this covers the common transient failures: pod restarts
    mid-request, DNS propagation lag, brief network blips. The breaker
    also prevents a bad downstream pod from exhausting calling threads
    while waiting on long timeouts.

    Streaming returns: when the downstream function returns a generator,
    serve.endpoints emits an `text/event-stream` body framed by
    sse_frame_stream. We detect that via Content-Type and return a
    Python generator (consume_sse_stream) that yields parsed event
    dicts. Retries only cover connect-time failures - once a stream is
    open, an in-flight error surfaces to the caller's iterator as a
    RuntimeError (we cannot replay events that were already consumed).
    """
    @hookimpl
    static def sv_service_call(module_name: str, func_name: str, args: dict) -> any {
        import from jac_scale.runtime.transport.transport { http_transport }
        return http_transport().call_function(module_name, func_name, args);
    }

    """Override core's sv_walker_call with auth forwarding, retry, and breaker.

    Mirrors `sv_service_call` for the walker-spawn flavour of sv-to-sv:
    POST to `/walker/<name>` rather than `/function/<name>`, decode the
    TransportResponse envelope, and rehydrate `data.result` into an
    instance of the consumer-side stub class via `stub_cls._from_wire`.
    The walker's `data.reports` list is attached to the rehydrated
    instance so call sites read `walker_inst.reports[0]` directly.

    Walker calls share the per-provider circuit breaker with function
    calls - both express the same liveness signal for the provider, so
    a breaker trip from either RPC kind protects the other. Auth and
    trace headers are forwarded the same way. SSE streaming is not
    plumbed for walkers (walker endpoints don't return generators); the
    Content-Type pivot from sv_service_call is intentionally absent.
    """
    @hookimpl
    static def sv_walker_call(
        module_name: str, walker_name: str, args: dict, stub_cls: any
    ) -> any {
        import from jac_scale.runtime.transport.transport { http_transport }
        return http_transport().call_walker(module_name, walker_name, args, stub_cls);
    }
}


# Pluggy's varnames() puts parameters with defaults into kwargnames, not argnames.
# But _multicall only passes argnames to hook implementations.
# JacRuntimeImpl strips defaults via build_plugin_hook_layer, so we must too.
import inspect;
glob func = JacScalePlugin.create_j_context,
     sig = inspect.signature(func),
     sig_nodef = sig.replace(
         parameters=[
             p.replace(default=inspect.Parameter.empty) for p in sig.parameters.values()
         ]
     );

with entry {
    func.__signature__ = sig_nodef;
    plugin_manager.register(JacScalePlugin());
}
