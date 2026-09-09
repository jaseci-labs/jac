import os;
import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.cli.console { console }
import from jaclang.project.kinds { RunPlan }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.server.server { JacAPIServer as JacServer }
import from .config.config_loader { get_scale_config }
import from .config.project_env { load_project_env }
import from .events.streams.postgres { PgEventStream }

import from jaclang.server.shared_store { shared_store as _pg_anchor }
import from .state.pg_state_backend { PgStateBackend as _state_anchor }
import from jaclang.server.server { ServerExtension }
import from jaclang.data.storage { Storage }
import from .observability.factory { UtilityFactory }
import from .deploy.target.factory { DeploymentTargetFactory }

obj DeployFactories {
    has utility: type[UtilityFactory],
        target: type[DeploymentTargetFactory];
}

def _load_deploy_factories -> DeployFactories {
    return DeployFactories(utility=UtilityFactory, target=DeploymentTargetFactory);
}

def _print_local_fleet_banner(fleet: any) {
    import from .runtime.fleet { format_fleet_lines }
    names = fleet.service_names();
    plural = "s" if len(names) != 1 else "";
    console.print(
        f"Fleet mode: {len(names)} service app{plural} "
        f"[{', '.join(names)}] running as local processes behind the gateway "
        f"hosted by '{fleet.root_app}'.",
        style="cyan"
    );
    for line in format_fleet_lines(fleet) {
        console.print(f"  {line}", style="muted");
    }
}

def scale_runtime_configured -> bool {
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

def mark_scale_runtime {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
}

def scale_local_serve(
    served: RunPlan,
    fleet: list[RunPlan],
    port: int = 8000,
    dev: bool = False,
    no_client: bool = False
) -> int | None {
    mark_scale_runtime();
    if not fleet or os.environ.get("JAC_SV_SIBLING") == "1" {
        return None;
    }
    import from jaclang.project.config { get_config }
    import from .runtime.fleet { fleet_from_plans }
    import from .runtime.realizer.local_realizer { LocalRealizer }

    cfg = get_config();
    if cfg is None {
        console.error("A fleet needs a jac.toml with [apps]; none was found.");
        return 1;
    }
    project_root = (
        str(cfg.project_root)
            if cfg.project_root
            else os.path.dirname(os.path.abspath(served.entry_path))
    );
    try {
        spec = fleet_from_plans(cfg, project_root, served, fleet);
    } except ValueError as e {
        console.error(f"Fleet configuration invalid: {e}", emoji=False);
        return 1;
    }
    gateway_cfg = get_scale_config().get_gateway_config();
    if port {
        gateway_cfg["gateway_port"] = int(port);
        gateway_cfg["gateway_port_pinned"] = True;
    }
    gateway_cfg["dev"] = dev and not no_client;
    gateway_cfg["app_serves_client"] = not no_client;
    _print_local_fleet_banner(spec);
    try {
        LocalRealizer(fleet=spec, gateway_config=gateway_cfg).serve();
    } except Exception as e {
        console.error(f"Fleet mode failed ({type(e).__name__}: {e}).", emoji=False);
        return 1;
    }
    return 0;
}

def scale_deploy(
    filename: str,
    target: str,
    enable_tls: bool,
    dry_run: bool,
    show_yaml: bool,
    served_app: str = ""
) -> int {
    mark_scale_runtime();
    try {
        import from jaclang.scale.runtime.realizer.kubernetes_realizer {
            KubernetesRealizer
        }
        return KubernetesRealizer(served_app=served_app).realize(
            filename, target, enable_tls, dry_run, show_yaml
        );
    } except Exception as e {
        console.error(f"Deploy failed: {e}", emoji=False);
        return 1;
    }
}

def _resolve_deploy_target(target: str) -> tuple[str, str, str] {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if target and target.endswith(".jac") {
        abs_path = os.path.abspath(target);
        owner = cfg.app_for_path(abs_path) if cfg is not None else None;
        return (abs_path, owner.name if owner is not None else "", "");
    }
    if cfg is None or cfg.project_root is None {
        return (
            "",
            "",
            "jac scale deploy needs a jac.toml project or the app's .jac file.\n"
            "  Usage: jac scale deploy [app | app.jac] [--target kubernetes]"
        );
    }
    try {
        app = cfg.resolve_app(target);
    } except ValueError as e {
        return ("", "", str(e));
    }
    import from jaclang.project.kinds { resolve_entry }
    project_root = str(cfg.project_root);
    eff = cfg.effective_for_app(app.name) if app.name in cfg.apps else cfg;
    entry_path = resolve_entry(eff, project_root, app);
    if not entry_path {
        return (
            "",
            "",
            f"App '{app.name}' has no entry file; expected "
            f"{app.entry_path(project_root)}"
        );
    }
    return (entry_path, "" if app.implicit else app.name, "");
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
    load_project_env(code_folder);

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
    load_project_env(code_folder);

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

comptime SPEC_SCALE_CMD: CommandSpec = CommandSpec(
         name="scale",
         help="Manage scale deployments: the local fleet of service apps (status/stop/restart/logs) and platform deployments (deploy/status/destroy of a workspace app)",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 help="Action: deploy, status, stop, restart, logs, destroy, gateway"
             ),
             Arg.create(
                 "service_name",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="App name (stop/restart/logs), the workspace app or .jac file to deploy, or a .jac app file for platform status/destroy"
             ),
             Arg.create(
                 "lines",
                 typ=int,
                 `default=50,
                 help="Number of log lines to show (for 'logs' action)"
             ),
             Arg.create(
                 "target",
                 typ=str,
                 `default="kubernetes",
                 help="Platform target for .jac app status/destroy (kubernetes, aws, gcp, etc.)"
             ),
             Arg.create(
                 "component",
                 typ=str,
                 `default="",
                 help="Platform destroy: component to remove (application, database, monitoring; default: entire deployment)"
             ),
             Arg.create(
                 "enable-tls",
                 typ=bool,
                 `default=False,
                 help="Platform deploy: enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB)",
                 short=""
             ),
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 help="Platform deploy: print the manifests that would be applied; touch nothing (no cluster contact, no downloads, no client build, no DB provisioning, no TLS issuance, no deploy tooling installed)",
                 short=""
             ),
             Arg.create(
                 "show-yaml",
                 typ=bool,
                 `default=False,
                 help="Platform deploy, with --dry-run: dump the raw YAML stream",
                 short=""
             ),

         ],
         examples=[
             (
                 "jac scale deploy",
                 "Deploy the workspace's default app and its service apps"
             ),
             (
                 "jac scale deploy web",
                 "Deploy a named workspace app as the gateway host"
             ),
             ("jac scale deploy app.jac", "Deploy a specific app file"),
             (
                 "jac scale deploy app.jac --target aws",
                 "Deploy the app to a specific platform target"
             ),
             (
                 "jac scale deploy --dry-run --show-yaml",
                 "Print the manifests that would be applied, touching nothing"
             ),
             ("jac scale status", "Show status of the local fleet"),
             ("jac scale stop orders", "Stop the orders app"),
             ("jac scale restart cart", "Restart the cart app"),
             ("jac scale logs products", "Show logs for the products app"),
             ("jac scale destroy", "Stop every app in the local fleet"),
             ("jac scale status app.jac", "Show platform deployment status of app"),
             ("jac scale destroy app.jac", "Remove app's platform deployment"),
             (
                 "jac scale destroy app.jac --component database",
                 "Remove only the database from the deployment"
             ),

         ],
         group="fleet",
         handler_name=ct_name(scale_cmd)
     );

def scale_cmd(
    action: str,
    service_name: str = "",
    lines: int = 50,
    target: str = "kubernetes",
    component: str = "",
    enable_tls: bool = False,
    dry_run: bool = False,
    show_yaml: bool = False
) -> int {
    if action == "deploy" {
        (app_file, served_app, problem) = _resolve_deploy_target(service_name);
        if problem {
            console.error(problem, emoji=False);
            return 1;
        }
        return scale_deploy(
            app_file, target, enable_tls, dry_run, show_yaml, served_app=served_app
        );
    }
    if action in ("status", "destroy") and service_name.endswith(".jac") {
        if action == "status" {
            return deploy_status(service_name, target);
        }
        return deploy_destroy(service_name, target, component);
    }
    import from jaclang.scale.runtime.fleet { fleet_from_config, fleet_from_env }
    import from jaclang.scale.runtime.orchestrator.orchestrator {
        ServiceRegistry,
        build_registry
    }
    import from jaclang.scale.runtime.orchestrator.local_deployer { LocalDeployer }

    scale_config = get_scale_config();
    gateway_cfg = scale_config.get_gateway_config();

    if action == "gateway" {
        import from jaclang.scale.runtime.orchestrator.orchestrator {
            start_gateway_only
        }
        fleet = fleet_from_env();
        if fleet is None {
            try {
                fleet = fleet_from_config(scale_config.get_jac_config());
            } except ValueError as e {
                console.error(f"Cannot assemble the fleet: {e}", emoji=False);
                return 1;
            }
        }
        start_gateway_only(fleet, gateway_cfg);
        return 0;
    }

    jac_config = scale_config.get_jac_config();
    if not jac_config.apps {
        console.print(
            "No apps declared: add [apps.<name>] tables to jac.toml "
            "(kind = \"service\" for fleet members).",
            style="error"
        );
        return 1;
    }
    try {
        fleet = fleet_from_config(jac_config);
    } except ValueError as e {
        console.error(f"Cannot assemble the fleet: {e}", emoji=False);
        return 1;
    }
    if fleet is None or not fleet.service_names() {
        console.print(
            "No service apps declared: add [apps.<name>] kind = \"service\" "
            "entries to jac.toml.",
            style="error"
        );
        return 1;
    }

    svc_registry: ServiceRegistry = build_registry(fleet);
    deployer = LocalDeployer(registry=svc_registry, target="local");

    if action == "status" {
        svc_status = deployer.status();
        console.print();
        console.print("  Fleet Status", style="bold cyan");
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
            console.print("App name required: jac scale stop <name>", style="error");
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
            console.print("App name required: jac scale restart <name>", style="error");
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
            console.print("App name required: jac scale logs <name>", style="error");
            return 1;
        }
        log_output = deployer.get_logs(service_name, lines);
        console.print(log_output);
    } elif action == "destroy" {
        deployer.destroy_all();
        console.success("All apps stopped", emoji=False);
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
        if not scale_runtime_configured() {
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

    static def get_server_extensions -> list[ServerExtension] {
        import from .server.extensions { scale_extensions }
        return scale_extensions();
    }

    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        import from .storage.factory { StorageFactory }
        return StorageFactory.get_default(base_path, create_dirs);
    }

    static def get_sv_registry -> dict[str, str] {
        import os;
        import from jaclang.server { sv_client }

        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            return dict(sv_client._registry);
        }

        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
                build_k8s_registry
            }
            import from jaclang.scale.runtime.fleet { fleet_from_env }
            fleet = fleet_from_env();
            names: list[str] = fleet.names() if fleet is not None else [];
            port: int = int(
                get_scale_config().get_gateway_config().get("gateway_port", 8000)
            );
            return build_k8s_registry(names, port);
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

    static def sv_service_call(
        app: str, func_name: str, args: dict, headers: dict[str, str] | None = None
    ) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_function(app, func_name, args, headers=headers);
    }

    static def sv_walker_call(
        app: str,
        walker_name: str,
        args: dict,
        stub_cls: any,
        headers: dict[str, str] | None = None
    ) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_walker(
            app, walker_name, args, stub_cls, headers=headers
        );
    }
}
