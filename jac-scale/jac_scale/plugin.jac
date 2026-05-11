"""File covering plugin implementation."""
import os;
import pathlib;
import from typing { Any }
import from dotenv { load_dotenv }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, CommandPriority, HookContext }
import from jaclang.cli.console { console }
import from rich.table { Table }
import from jaclang.jac0core.runtime { hookimpl, plugin_manager }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.server { JacAPIServer as JacServer }
import from .context { JScaleExecutionContext }
import from .serve { JacAPIServer }
import from .jserver.jfast_api { JFastApiServer }
import from .config_loader { get_scale_config }
import from .factories.deployment_factory { DeploymentTargetFactory }
import from .factories.registry_factory { ImageRegistryFactory }
import from .factories.utility_factory { UtilityFactory }
import from .abstractions.config.app_config { AppConfig }
import from .user_manager { JacScaleUserManager }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.storage { Storage }

"""Pre-hook for jac start command to handle microservice mode and --scale flag."""
def _scale_pre_hook(context: HookContext) -> None {
    # Microservice mode: services are spawned on-demand by core's BFS
    # discovery + our ensure_sv_service hookimpl. The pre-hook only
    # bootstraps the gateway for client-facing routing when enabled
    # and we're NOT already running as an sv sibling child.
    scale_config = get_scale_config();
    ms_config = scale_config.get_microservices_config();
    is_sv_sibling = os.environ.get("JAC_SV_SIBLING") == "1";

    if ms_config.get("enabled", False) and not is_sv_sibling {
        scale_flag = context.get_arg("scale", False);
        if not scale_flag {
            import from jac_scale.microservices.orchestrator { start_microservice_mode }
            start_microservice_mode(ms_config);
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 0);
            return;
        }
        # If --scale is set with microservices enabled, fall through to K8s deploy
    }

    scale = context.get_arg("scale", False);
    if scale {
        filename = context.get_arg("filename");
        target = context.get_arg("target", "kubernetes");
        if not os.path.exists(filename) {
            raise FileNotFoundError(f"File not found: '{filename}'");
        }
        code_folder = os.path.dirname(filename) or '.';
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

        # Handle --enable-tls: patch TLS on the live deployment (no redeploy)
        enable_tls = context.get_arg("enable_tls", False);
        if enable_tls {
            if not target_config.get('domain', '') {
                raise ValueError(
                    "No domain configured. Set 'domain' under [plugins.scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            if not target_config.get('cert_manager_email', '') {
                raise ValueError(
                    "No cert_manager_email configured. Set 'cert_manager_email' under [plugins.scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            app_name = target_config.get('app_name', 'jaseci');
            deployment_target.enable_tls(app_name);
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 0);
            return;
        }

        build = context.get_arg("build", False);
        experimental = context.get_arg("experimental", False);
        registry = context.get_arg("registry", "dockerhub");
        code_folder = os.path.relpath(code_folder);
        code_folder = pathlib.Path(code_folder).as_posix();
        base_file_path = os.path.basename(filename);
        # Resolve secrets from [plugins.scale.secrets] config
        deployment_target.secrets = scale_config.get_secrets_config();
        # Handle image registry if build is requested
        if build {
            image_registry = ImageRegistryFactory.create(registry, target_config);
            deployment_target.image_registry = image_registry;
        }
        # Create app config
        app_config = AppConfig(
            code_folder=code_folder,
            file_name=base_file_path,
            build=build,
            experimental=experimental
        );
        if experimental {
            console.print(
                "Installing Jaseci packages from repository (experimental mode)..."
            );
        } else {
            console.print("Installing Jaseci packages from PyPI...");
        }
        # Deploy
        result = deployment_target.deploy(app_config);
        if not result.success {
            raise RuntimeError(result.message or "Deployment failed");
        }
        if result.service_url {
            console.print(
                f"Deployment complete! Service available at: {result.service_url}"
            );
        }
        # Cancel normal start execution since we handled it
        context.set_data("cancel_execution", True);
        context.set_data("cancel_return_code", 0);
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
    console.print("[bold cyan]  Jac Scale - Deployment Status[/bold cyan]");
    console.print(
        f"  [bold]App:[/bold] {app_name}   [bold]Namespace:[/bold] {namespace}"
    );
    console.print();

    if error {
        console.print(f"  [bold red]Cannot connect to cluster:[/bold red] {error}");
        console.print();
        return;
    }

    table = Table(show_header=True, header_style="bold dim", box=None, padding=(0, 2));
    table.add_column("Component", min_width=18);
    table.add_column("Status", min_width=22);
    table.add_column("Pods", justify="right", min_width=6);

    status_display = {
        'running': '[bold green]● Running[/bold green]',
        'degraded': '[bold yellow]◑ Degraded[/bold yellow]',
        'pending': '[bold yellow]⟳ Pending[/bold yellow]',
        'restarting': '[bold red]↺ Restarting[/bold red]',
        'failed': '[bold red]✗ Failed[/bold red]',
        'not_deployed': '[dim]○ Not Deployed[/dim]',
        'unknown': '[dim]? Unknown[/dim]',

    };

    for comp in components {
        s = comp.get('status', 'unknown');
        ready = comp.get('ready', 0);
        total = comp.get('total', 0);
        icon = status_display.get(s, s);
        if s in ['not_deployed', 'unknown'] {
            pods_str = '-';
        } else {
            pods_str = f"{ready}/{total}";
        }
        table.add_row(comp.get('name', ''), icon, pods_str);
    }

    console.print(table);

    if urls {
        console.print("  [bold]Service URLs[/bold]");
        console.print(f"  [dim]{'─' * 48}[/dim]");
        if 'app' in urls {
            console.print(f"  [bold]Application:[/bold]   {urls['app']}");
        }
        if 'grafana' in urls {
            console.print(f"  [bold]Grafana:[/bold]       {urls['grafana']}");
        }
        if 'redis_insight' in urls {
            console.print(f"  [bold]RedisInsight:[/bold]  {urls['redis_insight']}");
        }
        if 'mongo_express' in urls {
            console.print(f"  [bold]Mongo Express:[/bold] {urls['mongo_express']}");
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
                    "build",
                    typ=bool,
                    default=False,
                    help="Build and push Docker image (with --scale)",
                    short="b"
                ),
                Arg.create(
                    "experimental",
                    typ=bool,
                    default=False,
                    help="Use experimental mode (install from repo instead of PyPI)",
                    short="e"
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),
                Arg.create(
                    "registry",
                    typ=str,
                    default="dockerhub",
                    help="Image registry (dockerhub, ecr, gcr, etc.)",
                ),
                Arg.create(
                    "enable-tls",
                    typ=bool,
                    default=False,
                    help="Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB)",
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
                    f"[bold red]ERROR:[/bold red] --component is only supported for the 'kubernetes' target."
                );
                return 1;
            }
            if component and component not in valid_components {
                console.print(
                    f"[bold red]ERROR:[/bold red] Invalid component '{component}'. Valid choices: {', '.join(
                        valid_components
                    )}"
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

            # Get target-specific config
            if target == 'kubernetes' {
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
                    f"[bold red]WARNING:[/bold red] You are about to delete component '{component}' from deployment '{app_name}'."
                );
            } else {
                console.print(
                    f"[bold red]WARNING:[/bold red] You are about to delete namespace '{namespace}' and all its associated resources."
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
            name="setup",
            help="Configure microservice mode - select which Jac files become services",
            args=[
                Arg.create(
                    "subcommand",
                    kind=ArgKind.POSITIONAL,
                    help="Setup type (currently: microservice)"
                ),
                Arg.create(
                    "add",
                    typ=str,
                    default="",
                    help="Add a service file to existing config"
                ),
                Arg.create(
                    "remove", typ=str, default="", help="Remove a service by name"
                ),
                Arg.create(
                    "list",
                    typ=bool,
                    default=False,
                    help="List currently configured services"
                ),

            ],
            examples=[
                (
                    "jac setup microservice",
                    "Interactive setup - select files, write config"
                ),
                ("jac setup microservice --list", "Show current microservice config"),
                ("jac setup microservice --add orders_app.jac", "Add a service"),
                ("jac setup microservice --remove orders", "Remove a service"),

            ],
            group="microservices",
            priority=CommandPriority.PLUGIN,
            source="jac-scale"
        )
        def setup_cmd(
            subcommand: str, add: str = "", remove: str = "", list: bool = False
        ) -> int {
            if subcommand != "microservice" {
                console.print(
                    f"[bold red]Unknown setup type:[/bold red] '{subcommand}'. Use 'microservice'."
                );
                return 1;
            }

            import from jac_scale.microservices.setup {
                run_setup,
                add_service,
                remove_service,
                list_services
            }

            if list {
                list_services(".");
            } elif add {
                add_service(".", add);
            } elif remove {
                remove_service(".", remove);
            } else {
                run_setup(".");
            }
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
            import from jac_scale.microservices.orchestrator { build_registry }
            import from jac_scale.microservices.local_deployer { LocalDeployer }

            scale_config = get_scale_config();
            ms_config = scale_config.get_microservices_config();

            if not ms_config.get("enabled", False) {
                console.print(
                    "[bold red]Microservice mode is not enabled in jac.toml[/bold red]"
                );
                return 1;
            }

            if not ms_config.get("routes", {}) {
                console.print(
                    "[bold red]No routes configured in [plugins.scale.microservices.routes][/bold red]"
                );
                return 1;
            }

            registry = build_registry(ms_config);
            deployer = LocalDeployer(registry=registry, target="local");

            if action == "status" {
                svc_status = deployer.status();
                console.print();
                console.print("[bold cyan]  Microservice Status[/bold cyan]");
                console.print();
                for (name, info) in svc_status.items() {
                    status_str = info.get("status", "unknown");
                    running = info.get("running", False);
                    port = info.get("port", 0);
                    pid = info.get("pid");
                    prefix = info.get("prefix", "");
                    if running {
                        console.print(
                            f"  [green]●[/green] {name:12s} {prefix:20s} port={port} pid={pid}"
                        );
                    } else {
                        console.print(
                            f"  [red]○[/red] {name:12s} {prefix:20s} (not running)"
                        );
                    }
                }
                console.print();
            } elif action == "stop" {
                if not service_name {
                    console.print(
                        "[bold red]Service name required: jac scale stop <name>[/bold red]"
                    );
                    return 1;
                }
                if deployer.stop_service(service_name) {
                    console.print(f"[green]Stopped {service_name}[/green]");
                } else {
                    console.print(f"[red]Failed to stop {service_name}[/red]");
                    return 1;
                }
            } elif action == "restart" {
                if not service_name {
                    console.print(
                        "[bold red]Service name required: jac scale restart <name>[/bold red]"
                    );
                    return 1;
                }
                if deployer.restart_service(service_name) {
                    console.print(f"[green]Restarted {service_name}[/green]");
                } else {
                    console.print(f"[red]Failed to restart {service_name}[/red]");
                    return 1;
                }
            } elif action == "logs" {
                if not service_name {
                    console.print(
                        "[bold red]Service name required: jac scale logs <name>[/bold red]"
                    );
                    return 1;
                }
                log_output = deployer.get_logs(service_name, lines);
                console.print(log_output);
            } elif action == "destroy" {
                deployer.destroy_all();
                console.print("[green]All services stopped[/green]");
            } else {
                console.print(f"[bold red]Unknown action:[/bold red] '{action}'");
                console.print("Actions: status, stop, restart, logs, destroy");
                return 1;
            }

            return 0;
        }
    }
}

"""Jac Scale Plugin Implementation."""
class JacScalePlugin {
    @hookimpl
    static def create_j_context(user_root: (str | None)) -> ExecutionContext {
        # Storage backend configured via environment (MONGODB_URI, etc.)
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
        import from .factories.storage_factory { StorageFactory }
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
        import from jac_scale.microservices._util {
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
    dicts. Retries only cover connect-time failures — once a stream is
    open, an in-flight error surfaces to the caller's iterator as a
    RuntimeError (we cannot replay events that were already consumed).
    """
    @hookimpl
    static def sv_service_call(module_name: str, func_name: str, args: dict) -> Any {
        import time;
        import from jaclang.runtimelib { sv_client }
        import from jaclang.runtimelib.sv_sse { consume_sse_stream }
        import from jac_scale.microservices._auth_ctx { get_current_auth }
        import from jac_scale.microservices._trace_ctx { get_current_trace }

        func_label = f"{module_name}.{func_name}";

        # Test clients take precedence (matches core) and bypass retry +
        # breaker - they're in-process TestClient instances; transient
        # transport errors are not a concern.
        if module_name in sv_client._test_clients {
            tc = sv_client._test_clients[module_name];
            stream_cm = tc.stream("POST", f"/function/{func_name}", json=args);
            resp = stream_cm.__enter__();
            ct = resp.headers.get("content-type", "");
            if ct.startswith("text/event-stream") {
                # Wrapper takes ownership of stream_cm.__exit__; do NOT
                # exit it here. Pass None for client (TestClient is
                # owned by sv_client._test_clients).
                return _wrap_sse_keepalive_scale(stream_cm, resp, None, func_label);
            }
            try {
                # Streaming responses don't auto-read the body; httpx
                # raises ResponseNotRead on .json() otherwise.
                resp.read();
                data = resp.json();
            } finally {
                stream_cm.__exit__(None, None, None);
            }
            return _unwrap_sv_envelope(data, module_name, func_name);
        }

        # Circuit breaker: short-circuit when OPEN + cooldown not elapsed.
        if _breaker_should_skip(module_name) {
            raise RuntimeError(
                f"sv-to-sv RPC '{module_name}.{func_name}' blocked by " + f"open circuit breaker (cooldown {int(
                    _BREAKER_COOLDOWN_SECONDS
                )}s)"
            );
        }

        url = sv_client.resolve_url(module_name);
        try {
            import httpx;
        } except ImportError {
            raise RuntimeError(
                "httpx is required for sv-to-sv RPC calls. " + "Install it via `pip install httpx`."
            );
        }

        headers: dict[str, str] = {};
        auth = get_current_auth();
        if auth {
            headers["Authorization"] = auth;
        }
        # Thread the trace id across the sv-import hop so downstream
        # service logs + its further sv calls carry the same correlator.
        trace = get_current_trace();
        if trace {
            headers["X-Trace-Id"] = trace;
        }

        max_attempts: int = 3;
        backoff: float = 0.1;  # doubles each attempt: 0.1, 0.2, 0.4
        last_err: Exception | None = None;

        rpc_timeout: float = _sv_rpc_timeout(module_name);

        for attempt in range(max_attempts) {
            try {
                # Use httpx.stream() so we can inspect Content-Type before
                # buffering the body. SSE replies stay open and feed the
                # consumer iterator; JSON replies are read fully then the
                # connection is closed in the finally branch.
                client = httpx.Client(timeout=rpc_timeout);
                stream_cm = client.stream(
                    "POST", f"{url}/function/{func_name}", json=args, headers=headers
                );
                resp = stream_cm.__enter__();
                ct = resp.headers.get("content-type", "");
                if ct.startswith("text/event-stream") {
                    # Streaming success: connection stays open. Record a
                    # transport success and hand back a generator that
                    # owns connection cleanup.
                    _breaker_record_success(module_name);
                    return _wrap_sse_keepalive_scale(
                        stream_cm, resp, client, func_label
                    );
                }
                try {
                    resp.read();
                    data = resp.json();
                } finally {
                    stream_cm.__exit__(None, None, None);
                    client.close();
                }
                _breaker_record_success(module_name);
                return _unwrap_sv_envelope(data, module_name, func_name);
            } except (httpx.RequestError, httpx.TimeoutException) as e {
                # Transport-level error: connect refused, read timeout,
                # DNS failure. Worth retrying - the downstream pod may
                # still be coming up or the network blip will clear.
                last_err = e;
                if attempt < max_attempts - 1 {
                    time.sleep(backoff);
                    backoff = backoff * 2.0;
                }
            }
        }

        # All retries exhausted on transport errors: count one failure
        # against the breaker. If this trips OPEN, subsequent calls
        # fail fast until cooldown.
        _breaker_record_failure(module_name);

        raise RuntimeError(
            f"sv-to-sv RPC '{module_name}.{func_name}' failed after " + f"{max_attempts} attempts: {last_err}"
        );
    }

    """Override core's sv_walker_call with auth forwarding, retry, and breaker.

    Mirrors `sv_service_call` for the walker-spawn flavour of sv-to-sv:
    POST to `/walker/<name>` rather than `/function/<name>`, decode the
    TransportResponse envelope, and rehydrate `data.result` into an
    instance of the consumer-side stub class via `stub_cls._from_wire`.
    The walker's `data.reports` list is attached to the rehydrated
    instance so call sites read `walker_inst.reports[0]` directly.

    Walker calls share the per-provider circuit breaker with function
    calls — both express the same liveness signal for the provider, so
    a breaker trip from either RPC kind protects the other. Auth and
    trace headers are forwarded the same way. SSE streaming is not
    plumbed for walkers (walker endpoints don't return generators); the
    Content-Type pivot from sv_service_call is intentionally absent.
    """
    @hookimpl
    static def sv_walker_call(
        module_name: str, walker_name: str, args: dict, stub_cls: Any
    ) -> Any {
        import time;
        import from jaclang.runtimelib { sv_client }
        import from jac_scale.microservices._auth_ctx { get_current_auth }
        import from jac_scale.microservices._trace_ctx { get_current_trace }

        label = f"{module_name}.{walker_name}";

        # In-process TestClient path: bypass retry + breaker, no transport.
        if module_name in sv_client._test_clients {
            tc = sv_client._test_clients[module_name];
            resp = tc.post(f"/walker/{walker_name}", json=args);
            data = resp.json();
            return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
        }

        if _breaker_should_skip(module_name) {
            raise RuntimeError(
                f"sv-to-sv walker spawn '{label}' blocked by " + f"open circuit breaker (cooldown {int(
                    _BREAKER_COOLDOWN_SECONDS
                )}s)"
            );
        }

        url = sv_client.resolve_url(module_name);
        try {
            import httpx;
        } except ImportError {
            raise RuntimeError(
                "httpx is required for sv-to-sv RPC calls. " + "Install it via `pip install httpx`."
            );
        }

        headers: dict[str, str] = {};
        auth = get_current_auth();
        if auth {
            headers["Authorization"] = auth;
        }
        trace = get_current_trace();
        if trace {
            headers["X-Trace-Id"] = trace;
        }

        max_attempts: int = 3;
        backoff: float = 0.1;
        last_err: Exception | None = None;

        rpc_timeout: float = _sv_rpc_timeout(module_name);

        for attempt in range(max_attempts) {
            try {
                client = httpx.Client(timeout=rpc_timeout);
                try {
                    resp = client.post(
                        f"{url}/walker/{walker_name}", json=args, headers=headers
                    );
                    data = resp.json();
                } finally {
                    client.close();
                }
                _breaker_record_success(module_name);
                return _hydrate_walker_envelope(
                    data, module_name, walker_name, stub_cls
                );
            } except (httpx.RequestError, httpx.TimeoutException) as e {
                last_err = e;
                if attempt < max_attempts - 1 {
                    time.sleep(backoff);
                    backoff = backoff * 2.0;
                }
            }
        }

        _breaker_record_failure(module_name);

        raise RuntimeError(
            f"sv-to-sv walker spawn '{label}' failed after " + f"{max_attempts} attempts: {last_err}"
        );
    }
}


"""Drive the SSE consumer against an already-entered Response, then
__exit__ the parent context manager (and close() the owning httpx
Client, if any) when the consumer is done iterating. Hoisted to
module scope because Jac doesn't support nested defs.

The TestClient branch passes `client=None` because the TestClient
instance is owned by sv_client._test_clients and outlives the call.
"""
def _wrap_sse_keepalive_scale(
    stream_cm: Any, resp: Any, client: Any, func_label: str
) -> Any {
    import from jaclang.runtimelib.sv_sse { consume_sse_stream }
    try {
        for ev in consume_sse_stream(resp, func_label) {
            yield ev;
        }
    } finally {
        try {
            stream_cm.__exit__(None, None, None);
        } except Exception {
            ;
        }
        if client {
            try {
                client.close();
            } except Exception {
                ;
            }
        }
    }
}

# P14: [plugins.scale.microservices.services.NAME].rpc_timeout overrides
# the default for LLM / long-running services.
glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(module_name: str) -> float {
    try {
        import from jac_scale.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        svc_cfg = ms_cfg.get("services", {}).get(module_name, {});
        if "rpc_timeout" in svc_cfg {
            return float(svc_cfg["rpc_timeout"]);
        }
    } except Exception {
        # Fall through on config read failure (e.g. no jac.toml in tests).
        ;
    }
    return _SV_DEFAULT_RPC_TIMEOUT;
}


# =============================================================================
# Per-provider circuit breaker state for sv_service_call (ROADMAP P6).
#
# Each provider module gets its own CLOSED/OPEN/HALF_OPEN state machine:
#   CLOSED     - normal. Track consecutive transport failures.
#   OPEN       - tripped. Fail fast; skip httpx.post entirely until
#                cooldown elapses.
#   HALF_OPEN  - cooldown passed. Let the next call through as a probe.
#                Success -> CLOSED (and reset counters). Failure -> OPEN.
#
# Breaker trips on exhausted-retry transport failures only. Application
# envelope errors (ok=false) are deterministic and say nothing about
# whether the provider is reachable, so they do NOT count as failures.
#
# State is process-local (dict + lock). In K8s each pod has its own
# breaker; one misbehaving pod doesn't trip its siblings.
# =============================================================================
import from threading { Lock as _BreakerLock }
glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _breaker_state: dict[str, dict] = {},
     _breaker_lock = _BreakerLock();

"""Check whether a call to `provider` should short-circuit.

Returns True when the breaker is OPEN and the cooldown hasn't elapsed
(caller must raise without hitting the network). Returns False when
CLOSED or when cooldown has elapsed (in which case this call also
transitions OPEN -> HALF_OPEN so the caller's request acts as the
probe).
"""
def _breaker_should_skip(provider: str) -> bool {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None or st.get("state") == "CLOSED" {
            return False;
        }
        if st.get("state") == "OPEN" {
            elapsed = time.time() - st.get("opened_at", 0.0);
            if elapsed < _BREAKER_COOLDOWN_SECONDS {
                return True;
            }
            # Cooldown elapsed: transition to HALF_OPEN so THIS call
            # becomes the probe.
            st["state"] = "HALF_OPEN";
            return False;
        }
        # HALF_OPEN: let the probe through
        return False;
    }
}

"""Record a successful call to `provider`; resets breaker to CLOSED."""
def _breaker_record_success(provider: str) {
    with _breaker_lock {
        _breaker_state[provider] = {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
    }
}

"""Record a transport failure against `provider`.

From CLOSED, after N consecutive failures the breaker trips OPEN.
From HALF_OPEN, any failure re-trips OPEN immediately (probe failed).
"""
def _breaker_record_failure(provider: str) {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider)
        or {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
        current = st.get("state", "CLOSED");
        if current == "HALF_OPEN" {
            st["state"] = "OPEN";
            st["opened_at"] = time.time();
        } else {
            st["fails"] = st.get("fails", 0) + 1;
            if st["fails"] >= _BREAKER_TRIP_THRESHOLD {
                st["state"] = "OPEN";
                st["opened_at"] = time.time();
            }
        }
        _breaker_state[provider] = st;
    }
}

"""Test-only: clear breaker state for a provider."""
def _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

"""Test-only: snapshot the breaker state dict for a provider (or None)."""
def _breaker_peek(provider: str) -> dict | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

"""Test-only: force the cooldown clock into the past so the next
_breaker_should_skip call transitions OPEN -> HALF_OPEN without the
test having to wait _BREAKER_COOLDOWN_SECONDS.
"""
def _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}

"""Unwrap a TransportResponse envelope from an sv-service RPC response.

Shared between the retry and test-client paths in sv_service_call so
both observe the same error semantics. Raises RuntimeError with the
envelope's error message when ok=false.
"""
def _unwrap_sv_envelope(data: Any, module_name: str, func_name: str) -> Any {
    if isinstance(data, dict) and data.get("ok") {
        result_envelope = data.get("data");
        if isinstance(result_envelope, dict) and ("result" in result_envelope) {
            return result_envelope["result"];
        }
        return result_envelope;
    }
    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise RuntimeError(
        f"sv-to-sv RPC '{module_name}.{func_name}' failed: {msg or 'unknown error'}"
    );
}

"""Rehydrate a /walker/<name> response envelope into a stub instance.

The wire envelope has both `data.result` (the executed walker as a
dict with `_jac_type` / `_jac_id` / `_jac_archetype` / has-fields)
and `data.reports` (the list of values the walker emitted via
`report`). We hand back an instance of the consumer-side stub class
with the has-fields populated and `reports` attached, so call sites
can read both like a locally-spawned walker. Raises RuntimeError on
envelope-level failure, matching `_unwrap_sv_envelope`.
"""
def _hydrate_walker_envelope(
    data: Any, module_name: str, walker_name: str, stub_cls: Any
) -> Any {
    if isinstance(data, dict) and data.get("ok") {
        envelope = data.get("data") or {};
        result_dict = envelope.get("result") if isinstance(envelope, dict) else None;
        reports = envelope.get("reports") if isinstance(envelope, dict) else None;
        instance = stub_cls._from_wire(result_dict)
            if (stub_cls is not None and result_dict is not None)
            else result_dict;
        if instance is not None and reports is not None {
            try {
                instance.reports = reports;
            } except Exception {
                ;
            }
        }
        return instance;
    }
    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise RuntimeError(
        f"sv-to-sv walker spawn '{module_name}.{walker_name}' failed: {msg
        or 'unknown error'}"
    );
}

# Pluggy's varnames() puts parameters with defaults into kwargnames, not argnames.
# But _multicall only passes argnames to hook implementations.
# JacRuntimeInterfaceImpl strips defaults via generate_plugin_helpers, so we must too.
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
