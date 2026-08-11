import os;
import pathlib;
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.server { JacAPIServer as JacServer }
import from .config.config_loader { get_scale_config }
import from .events.streams.postgres { PgEventStream }

import from .persistence.pg { shared_store as _pg_anchor }
import from .state.pg_state_backend { PgStateBackend as _state_anchor }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.storage { Storage }

obj DeployFactories {
    has utility: type,
        target: type;
}

def _load_deploy_factories -> DeployFactories {
    import from .observability.factory { UtilityFactory }
    import from .deploy.target.factory { DeploymentTargetFactory }
    return DeployFactories(utility=UtilityFactory, target=DeploymentTargetFactory);
}

def _print_local_ms_banner(routes: dict[str, str]) {
    import from .runtime.routing { format_route_lines }
    names = sorted(routes.keys());
    plural = "s" if len(names) != 1 else "";
    console.print(
        f"Microservice mode: {len(names)} service{plural} "
        f"[{', '.join(names)}], running locally as subprocesses with no "
        f"Docker images.",
        style="cyan"
    );
    for line in format_route_lines(routes) {
        console.print(f"  {line}", style="muted");
    }
}

def _scale_runtime_active -> bool {
    if (
        os.environ.get("JAC_SCALE_RUNTIME") == "1"
        or os.environ.get("JAC_SV_SIBLING") == "1"
    ) {
        return True;
    }
    db = get_scale_config().get_database_config();
    return bool(
        db.get("url") or db.get("postgres_url") or os.environ.get("JAC_DB_URL")
    );
}

def scale_start(
    filename: str,
    scale: bool,
    target: str,
    enable_tls: bool,
    dry_run: bool,
    show_yaml: bool,
    port: int = 8000
) -> int | None {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    scale_config = get_scale_config();
    ms_config = scale_config.get_microservices_config();
    if port and port != 8000 {
        ms_config["gateway_port"] = port;
    }
    is_sv_sibling = os.environ.get("JAC_SV_SIBLING") == "1";

    enabled = ms_config.get("enabled", None);
    if (not is_sv_sibling) and (not scale) and (enabled is not False) {
        realizer = None;
        should_serve_ms = False;
        try {
            import from jaclang.scale.runtime.routing {
                resolve_routes,
                resolve_service_files
            }
            ms_config["routes"] = resolve_routes(ms_config);
            ms_config["service_files"] = resolve_service_files(
                ms_config, ms_config["routes"]
            );
            if ms_config["routes"] {
                import from jaclang.scale.runtime.routing { ensure_main_service }
                ensure_main_service(
                    ms_config["routes"],
                    ms_config["service_files"],
                    os.path.basename(filename)
                );
            }

            import from jaclang.scale.runtime.realizer.local_realizer { LocalRealizer }
            realizer = LocalRealizer(ms_config=ms_config);
            should_serve_ms = realizer.should_serve(enabled);
        } except ValueError as e {
            console.error(f"Microservice configuration invalid: {e}", emoji=False);
            return 1;
        } except Exception as e {
            console.error(
                f"Microservice mode unavailable "
                f"({type(e).__name__}: {e}); starting as a monolith.",
                emoji=False
            );
            realizer = None;
            should_serve_ms = False;
        }
        if should_serve_ms and realizer is not None {
            if enabled is None {
                _print_local_ms_banner(ms_config.get("routes", {}));
            }
            realizer.serve();
            return 0;
        }
    }

    if scale {
        import from jaclang.scale.runtime.realizer.kubernetes_realizer {
            KubernetesRealizer
        }
        try {
            return KubernetesRealizer(ms_config=ms_config).realize(
                filename, target, enable_tls, dry_run, show_yaml
            );
        } except Exception as e {
            console.error(f"Deploy failed: {e}", emoji=False);
            return 1;
        }
    }

    return None;
}

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
        console.print();
    }
}

glob registry = get_registry();

def deploy_destroy(
    file_path: str, target: str = "kubernetes", component: str = ""
) -> int {
    if not os.path.exists(file_path) {
        raise FileNotFoundError(f"File not found: '{file_path}'");
    }

    valid_components = ["application", "database", "monitoring"];
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
    import from dotenv { load_dotenv }
    load_dotenv(dotenv_path);

    scale_config = get_scale_config();

    factories = _load_deploy_factories();
    logger = factories.utility.create_logger('standard');

    if target in ('kubernetes', 'kubernetes-microservice') {
        target_config = scale_config.get_kubernetes_config();
    } else {
        target_config = scale_config.get_section(target);
    }

    app_name = target_config.get('app_name', 'jaseci');
    namespace = target_config.get('namespace', 'default');

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
    confirmation = input("Are you sure you want to proceed? (y/n): ").strip().lower();
    if confirmation != 'y' {
        console.print("Destroy cancelled.");
        return 1;
    }

    deployment_target = factories.target.create(target, target_config, logger);
    deployment_target.destroy(app_name, component);

    if component {
        console.print(
            f"Successfully destroyed component '{component}' from '{app_name}'"
        );
    } else {
        console.print(f"Successfully destroyed deployment '{app_name}' from {target}");
    }
    return 0;
}

def deploy_status(file_path: str, target: str = "kubernetes") -> int {
    if not os.path.exists(file_path) {
        raise FileNotFoundError(f"File not found: '{file_path}'");
    }
    code_folder = os.path.dirname(file_path) or '.';
    dotenv_path = os.path.join(code_folder, '.env');
    import from dotenv { load_dotenv }
    load_dotenv(dotenv_path);

    scale_config = get_scale_config();

    factories = _load_deploy_factories();
    logger = factories.utility.create_logger('standard');

    if target == 'kubernetes' {
        target_config = scale_config.get_kubernetes_config();
    } else {
        target_config = scale_config.get_section(target);
    }

    deployment_target = factories.target.create(target, target_config, logger);
    app_name = target_config.get('app_name', 'jaseci');

    status_data = deployment_target.get_full_status(app_name);
    _print_deployment_status(status_data);
    return 0;
}

def _scale_split(module_name: str) -> int {
    import tomllib;
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    import from .runtime.routing { derive_route_prefix, guard_route_name }

    if not module_name {
        console.print("Module name required: jac scale split <module>", style="error");
        return 1;
    }
    name = module_name[:-4] if module_name.endswith(".jac") else module_name;
    try {
        guard_route_name(name);
    } except ValueError as e {
        console.print(str(e), style="error");
        return 1;
    }
    proj_root = find_jac_project_root(os.getcwd());
    if not proj_root {
        console.print(
            "No jac.toml found: run `jac scale split` inside a jac project.",
            style="error"
        );
        return 1;
    }
    toml_path = pathlib.Path(proj_root) / "jac.toml";
    text = toml_path.read_text(encoding="utf-8") if toml_path.exists() else "";
    try {
        doc = tomllib.loads(text);
    } except Exception as e {
        console.print(f"Cannot parse {toml_path}: {e}", style="error");
        return 1;
    }
    declared = (
        doc.get("scale", {}).get("microservices", {}).get("routes", {})
        or doc.get("plugins", {}).get("scale", {}).get("microservices", {}).get(
            "routes", {}
        )
    );
    if name in declared {
        console.print(
            f"Service '{name}' is already declared "
            f"([scale.microservices.routes] -> {declared[name]}).",
            style="muted"
        );
        return 0;
    }
    prefix = derive_route_prefix(name);
    header = "[scale.microservices.routes]";
    entry_line = name + ' = "' + prefix + '"';
    lines = text.splitlines();
    header_idx = -1;
    for (i, ln) in enumerate(lines) {
        if ln.strip() == header {
            header_idx = i;
            break;
        }
    }
    if header_idx >= 0 {
        lines.insert(header_idx + 1, entry_line);
        new_text = "\n".join(lines);
        if text.endswith("\n") {
            new_text += "\n";
        }
    } else {
        base = text if (not text or text.endswith("\n")) else text + "\n";
        sep = "\n" if base else "";
        new_text = f"{base}{sep}{header}\n{entry_line}\n";
    }
    toml_path.write_text(new_text, encoding="utf-8");
    console.success(
        f"Declared service '{name}' -> {prefix} in {toml_path}", emoji=False
    );
    return 0;
}


@registry.command(
    name="scale",
    help="Manage scale deployments: local microservices (status/stop/restart/logs) and platform deployments (status/destroy on a .jac app)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            help="Action: status, stop, restart, logs, destroy, split"
        ),
        Arg.create(
            "service_name",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Service name (stop/restart/logs), module to declare as a service (split), or a .jac app file for platform status/destroy"
        ),
        Arg.create(
            "lines",
            typ=int,
            default=50,
            help="Number of log lines to show (for 'logs' action)"
        ),
        Arg.create(
            "target",
            typ=str,
            default="kubernetes",
            help="Platform target for .jac app status/destroy (kubernetes, aws, gcp, etc.)"
        ),
        Arg.create(
            "component",
            typ=str,
            default="",
            help="Platform destroy: component to remove (application, database, monitoring; default: entire deployment)"
        ),

    ],
    examples=[
        ("jac scale status", "Show status of all microservices"),
        (
            "jac scale split orders",
            "Declare the orders module as a service in [scale.microservices.routes]"
        ),
        ("jac scale stop orders", "Stop the orders service"),
        ("jac scale restart cart", "Restart the cart service"),
        ("jac scale logs products", "Show logs for products service"),
        ("jac scale destroy", "Stop all services"),
        ("jac scale status app.jac", "Show platform deployment status of app"),
        ("jac scale destroy app.jac", "Remove app's platform deployment"),
        (
            "jac scale destroy app.jac --component database",
            "Remove only the database from the deployment"
        ),

    ],
    group="microservices"
)
def scale_cmd(
    action: str,
    service_name: str = "",
    lines: int = 50,
    target: str = "kubernetes",
    component: str = ""
) -> int {
    if action in ("status", "destroy") and service_name.endswith(".jac") {
        if action == "status" {
            return deploy_status(service_name, target);
        }
        return deploy_destroy(service_name, target, component);
    }
    if action == "split" {
        return _scale_split(service_name);
    }
    import from jaclang.scale.runtime.orchestrator.orchestrator {
        ServiceRegistry,
        build_registry
    }
    import from jaclang.scale.runtime.orchestrator.local_deployer { LocalDeployer }

    scale_config = get_scale_config();
    ms_config = scale_config.get_microservices_config();

    is_fleet_pod = os.environ.get("JAC_SV_SIBLING") == "1";
    if ms_config.get("enabled", None) is False
        and not (action == "gateway" and is_fleet_pod) {
        console.print(
            "Microservice mode is disabled (enabled = false in jac.toml).",
            style="error"
        );
        return 1;
    }

    import from jaclang.scale.runtime.routing { resolve_routes, resolve_service_files }
    resolved_routes = resolve_routes(ms_config);
    if resolved_routes {
        ms_config["routes"] = resolved_routes;
        ms_config["service_files"] = resolve_service_files(ms_config, resolved_routes);
    } else {
        console.print(
            "No microservices declared: add entries to "
            "[scale.microservices.routes] in jac.toml "
            "(`jac scale split <module>` adds one).",
            style="error"
        );
        return 1;
    }

    registry: ServiceRegistry = build_registry(ms_config);
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
        import from jaclang.scale.runtime.orchestrator.orchestrator {
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

class JacScalePlugin {
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext | None {
        if not _scale_runtime_active() {
            return None;
        }
        import from .memory.context { JScaleExecutionContext }
        ctx = JScaleExecutionContext();
        if user_root is not None {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    static def create_server(jac_server: JacServer, host: str, port: int) {
        return None;
    }

    static def get_api_server_class -> type | None {
        try {
            import from .server.serve { JacAPIServer }
        } except ImportError as e {
            import logging;
            logging.getLogger(__name__).debug(
                "scale API server unavailable, falling back to core server: "
                f"missing module '{e?.name or ''}' ({e})"
            );
            return None;
        }
        return JacAPIServer;
    }

    static def get_user_manager(base_path: str) -> UserManager | None {
        if not _scale_runtime_active() {
            return None;
        }
        try {
            import from .identity.user_manager { JacScaleUserManager }
        } except ImportError {
            return None;
        }
        return JacScaleUserManager(base_path=base_path);
    }

    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        import from .storage.factory { StorageFactory }
        return StorageFactory.get_default(base_path, create_dirs);
    }

    static def ensure_sv_service(module_name: str, base_path: str) -> None {
        import os;
        import atexit;
        import subprocess;
        import from jaclang.runtimelib { sv_client }
        import from pathlib { Path }
        import from jaclang.scale.runtime.context.util {
            pick_free_port,
            jac_executable,
            wait_for_health
        }

        if module_name in sv_client._registry {
            return;
        }
        if module_name in sv_client._test_clients {
            return;
        }

        if "KUBERNETES_SERVICE_HOST" in os.environ {
            try {
                import from jaclang.scale.config.config_loader { get_scale_config }
                import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
                    k8s_safe_name
                }
                import from jaclang.scale.runtime.context.util {
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

        child_env = dict(os.environ);
        child_env["JAC_SV_SIBLING"] = "1";

        cmd = [jac_executable()]
            + sv_client.headless_start_args(str(module_file), port);

        log_dir = base_dir / '.jac' / 'logs';
        log_dir.mkdir(parents=True, exist_ok=True);
        log_path = log_dir / f"{module_name}.log";
        log_file = open(log_path, 'ab');
        try {
            proc = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env=child_env,
                cwd=str(base_dir)
            );
        } finally {
            log_file.close();
        }

        if not wait_for_health(base_url, lambda { proc.poll() is None; }) {
            proc.terminate();
            raise RuntimeError(
                f"sv-to-sv service '{module_name}' did not become healthy at "
                f"{base_url}; see {log_path} for the service's output"
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

    static def get_sv_registry -> dict[str, str] {
        import os;
        import from jaclang.runtimelib { sv_client }

        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            return dict(sv_client._registry);
        }

        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
                build_k8s_registry
            }
            ms_cfg = get_scale_config().get_microservices_config();
            routes: dict[str, str] = ms_cfg.get("routes", {});
            port: int = int(ms_cfg.get("gateway_port", 8000));
            return build_k8s_registry(routes, port);
        } except Exception as e {
            import logging;
            logging.getLogger(__name__).warning(
                f"K8s get_sv_registry fell back to local registry: {e}"
            );
            return dict(sv_client._registry);
        }
    }

    static def sv_transport_available -> bool {
        return True;
    }

    static def sv_service_call(module_name: str, func_name: str, args: dict) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_function(module_name, func_name, args);
    }

    static def sv_walker_call(
        module_name: str, walker_name: str, args: dict, stub_cls: any
    ) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_walker(module_name, walker_name, args, stub_cls);
    }
}
