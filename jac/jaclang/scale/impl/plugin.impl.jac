impl _load_deploy_factories -> DeployFactories {
    return DeployFactories(utility=UtilityFactory, target=DeploymentTargetFactory);
}

impl _print_local_fleet_banner(fleet: any) {
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

impl scale_local_serve(
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

impl scale_deploy(
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

impl _resolve_deploy_target(target: str) -> tuple[str, str, str] {
    import from pathlib { Path }

    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if target and target.endswith(".jac") {
        abs_path = os.path.abspath(target);
        selected_app = cfg.app_for_path(abs_path) if cfg is not None else None;
        return (abs_path, selected_app.name if selected_app is not None else "", "");
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

impl _print_deployment_status(status_data: dict[str, any]) -> None {
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
        'active': '● Active',
        'activating': '⟳ Activating',
        'deactivating': '⟳ Deactivating',
        'inactive': '◌ Inactive (scaled to zero)',
        'degraded': '✗ Degraded',
        'not_deployed': '○ Not Deployed',
        'unknown': '? Unknown',

    };
    status_style = {
        'active': 'bold green',
        'activating': 'bold yellow',
        'deactivating': 'bold yellow',
        'inactive': 'bold dim',
        'degraded': 'bold red',
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

impl deploy_destroy(
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

    (code_folder, _) = deployed_tree(file_path);
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

impl deploy_status(file_path: str, target: str = "kubernetes") -> int {
    if not os.path.exists(file_path) {
        raise FileNotFoundError(f"File not found: '{file_path}'");
    }
    (code_folder, _) = deployed_tree(file_path);
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

impl scale_cmd(
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
