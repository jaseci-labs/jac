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
import from .factories.deployment_factory { DeploymentTargetFactory }
import from .factories.registry_factory { ImageRegistryFactory }
import from .factories.utility_factory { UtilityFactory }
import from .abstractions.config.app_config { AppConfig }
import from .user_manager { JacScaleUserManager }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.storage { Storage }

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
        "  Run `jac setup microservice` to customize routes/ports/scaling/deploy.",
        style="muted"
    );
}

def _scale_pre_hook(context: HookContext) -> None {
    scale_config = get_scale_config();
    ms_config = scale_config.get_microservices_config();
    is_sv_sibling = os.environ.get("JAC_SV_SIBLING") == "1";
    scale_flag = context.get_arg("scale", False);

    enabled = ms_config.get("enabled", None);
    if (not is_sv_sibling) and (not scale_flag) and (enabled is not False) {
        filename = context.get_arg("filename");
        discovered: dict[str, str] = {};
        if filename and ((enabled is None) or (not ms_config.get("routes", {}))) {
            import from jac_scale.microservices.discovery { discover_sv_services }
            discovered = discover_sv_services(filename);
        }
        import from jac_scale.microservices.discovery { should_enter_local_ms }
        if should_enter_local_ms(
            enabled, is_sv_sibling, scale_flag, bool(discovered)
        ) {
            auto_detected: bool = enabled is None;
            if not ms_config.get("routes", {}) {
                ms_config["routes"] = discovered;
            }
            if auto_detected {
                _print_autodetect_banner(ms_config.get("routes", {}));
            }
            import from jac_scale.microservices.orchestrator.orchestrator {
                start_microservice_mode
            }
            start_microservice_mode(ms_config);
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 0);
            return;
        }
    }

    if scale_flag {
        filename = context.get_arg("filename");
        target = context.get_arg("target", "kubernetes");
        if target == "kubernetes" and enabled is not False {
            scale_discovered: dict[str, str] = {};
            needs_discovery = (enabled is None)
            or (enabled is True and not ms_config.get("routes", {}));
            if needs_discovery and filename and os.path.exists(filename) {
                import from jac_scale.microservices.discovery { discover_sv_services }
                scale_discovered = discover_sv_services(filename);
            }
            if (enabled is True) or scale_discovered {
                target = "kubernetes-microservice";
                if scale_discovered and not ms_config.get("routes", {}) {
                    raw_cfg = get_scale_config().load();
                    raw_ms = raw_cfg.setdefault("microservices", {});
                    if not raw_ms.get("routes") {
                        raw_ms["routes"] = scale_discovered;
                    }
                    names = ", ".join(sorted(scale_discovered.keys()));
                    label = "auto-detected" if enabled is None else "default routes";
                    console.print(
                        f"Microservice mode ({label}): {len(scale_discovered)} "
                        f"services [{names}], routes /api/<name>. Deploying to "
                        f"kubernetes; run `jac setup microservice` to customize.",
                        style="cyan"
                    );
                }
            }
        }
        if not os.path.exists(filename) {
            raise FileNotFoundError(f"File not found: '{filename}'");
        }
        code_folder = os.path.dirname(filename) or '.';
        dotenv_path = os.path.join(code_folder, '.env');
        load_dotenv(dotenv_path);
        scale_config = get_scale_config();
        logger = UtilityFactory.create_logger('standard');
        if target in ('kubernetes', 'kubernetes-microservice') {
            target_config = scale_config.get_kubernetes_config();
        } else {
            target_config = scale_config.get_section(target);
        }
        deployment_target = DeploymentTargetFactory.create(
            target, target_config, logger
        );

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
        deployment_target.secrets = scale_config.get_secrets_config();
        if build {
            image_registry = ImageRegistryFactory.create(registry, target_config);
            deployment_target.image_registry = image_registry;
        }
        no_image = context.get_arg("no_image", False);
        if no_image and target != "kubernetes-microservice" {
            console.warning(
                "--no-image only applies to microservice mode "
                "(kubernetes-microservice target); ignoring it."
            );
            no_image = False;
        }
        auto_no_image = False;
        if (target == "kubernetes-microservice") and (not no_image) {
            import from jac_scale.targets.kubernetes.microservice.source_bundle {
                auto_no_image_fallback,
                decide_zeroconfig_image_strategy,
                docker_usable,
                cluster_is_local,
                IMAGE_STRATEGY_NO_IMAGE
            }
            raw_k8s = scale_config.load().get("kubernetes", {});
            default_image = f"{target_config.get('app_name', 'jaseci')}:latest";
            if auto_no_image_fallback(
                build,
                str(target_config.get("docker_image_name", "") or ""),
                default_image,
                str(raw_k8s.get("image_registry", "") or "")
            ) {
                strategy = decide_zeroconfig_image_strategy(
                    docker_usable(), cluster_is_local()
                );
                console.print(f"Zero-config deploy: {strategy.reason}", style="cyan");
                if strategy.mode == IMAGE_STRATEGY_NO_IMAGE {
                    no_image = True;
                    auto_no_image = True;
                }
            }
        }
        app_config = AppConfig(
            code_folder=code_folder,
            file_name=base_file_path,
            build=build,
            experimental=experimental,
            no_image=no_image
        );
        if no_image {
            deployment_target.no_image = True;
            if auto_no_image {
                console.warning(
                    "No image or registry configured - falling back to "
                    "for production-ready apps."
                );
            } else {
                console.warning(
                    "no-image mode: copying local source into the cluster and "
                    "- build and push a real image for production-ready apps."
                );
            }
            console.warning(
                "Run `jac setup microservice` to configure resources, "
                "scaling, ingress, and secrets before going to production."
            );
            console.warning(
                "Source is uploaded to a Kubernetes ConfigMap. Secret files "
                "or in .env, never inline in committed source."
            );
        }
        if experimental {
            console.print(
                "Installing Jaseci packages from repository (experimental mode)..."
            );
        } elif target == "kubernetes-microservice" {
            import from jac_scale.microservices.images.build_helpers {
                find_jaseci_repo_root
            }
            repo = find_jaseci_repo_root(pathlib.Path(code_folder).resolve());
            if repo is not None {
                console.print(
                    f"Preparing microservice deployment (local source: {repo})..."
                );
            } else {
                console.print(
                    "Preparing microservice deployment (jaseci from PyPI)..."
                );
            }
        } else {
            console.print("Installing Jaseci packages from PyPI...");
        }
        dry_run = context.get_arg("dry_run", False);
        if dry_run {
            if target != "kubernetes-microservice" {
                console.warning(
                    f"--dry-run only supported with kubernetes-microservice target (got {target!r})."
                );
                context.set_data("cancel_execution", True);
                context.set_data("cancel_return_code", 1);
                return;
            }
            show_yaml: bool = bool(context.get_arg("show_yaml", False));
            try {
                import from jac_scale.microservices.cli.plan { print_plan }
                import from jac_scale.microservices.cli.diagnostics { has_errors }
                (bundle, diagnostics) = print_plan(
                    deployment_target, app_config, show_yaml=show_yaml
                );
                exit_code = 2 if has_errors(diagnostics) else 0;
            } except Exception as e {
                console.error(f"--dry-run failed: {e}", emoji=False);
                context.set_data("cancel_execution", True);
                context.set_data("cancel_return_code", 1);
                return;
            }
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", exit_code);
            return;
        }

        if target == "kubernetes-microservice" and not no_image {
            deployment_target.auto_build = True;
            deployment_target.guard_fallback_image = True;
        }

        try {
            result = deployment_target.deploy(app_config);
        } except Exception as e {
            console.error(f"Deployment failed: {e}", emoji=False);
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 1);
            return;
        }
        if not result.success {
            console.error(
                f"Deployment failed: {result.message or 'unknown error'}", emoji=False
            );
            context.set_data("cancel_execution", True);
            context.set_data("cancel_return_code", 1);
            return;
        }
        if result.service_url {
            console.print(
                f"Deployment complete! Service available at: {result.service_url}"
            );
        }
        context.set_data("cancel_execution", True);
        context.set_data("cancel_return_code", 0);
    }
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
        if 'redis_insight' in urls {
            console.print(f"  RedisInsight:  {urls['redis_insight']}", style="bold");
        }
        if 'mongo_express' in urls {
            console.print(f"  Mongo Express: {urls['mongo_express']}", style="bold");
        }
        console.print();
    }
}

class JacCmd {
    @hookimpl
    static def create_cmd {
        ;
        registry = get_registry();

        registry.extend_command(
            "start",
            args=[
                Arg.create(
                    "scale",
                    typ=bool,
                    default=False,
                    help="Deploy to a target platform instead of running locally",
                    short=""
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
                    "no-image",
                    typ=bool,
                    default=False,
                    help="Force no-image microservice deploy (copy local source + install jac at pod startup). Auto-enabled when no image/registry is configured; pass this to force it even when they are (dev/preview only; use a real image for production)",
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

            scale_config = get_scale_config();

            logger = UtilityFactory.create_logger('standard');

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
            confirmation = input(
                "Are you sure you want to proceed? (y/n): "
            ).strip().lower();
            if confirmation != 'y' {
                console.print("Destroy cancelled.");
                return 1;
            }

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

            scale_config = get_scale_config();

            logger = UtilityFactory.create_logger('standard');

            if target == 'kubernetes' {
                target_config = scale_config.get_kubernetes_config();
            } else {
                target_config = scale_config.get_section(target);
            }

            deployment_target = DeploymentTargetFactory.create(
                target, target_config, logger
            );
            app_name = target_config.get('app_name', 'jaseci');

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
                    f"Unknown setup type: '{subcommand}'. Use 'microservice'.",
                    style="error"
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
            import from jac_scale.microservices.orchestrator.orchestrator {
                build_registry
            }
            import from jac_scale.microservices.local_deployer { LocalDeployer }

            scale_config = get_scale_config();
            ms_config = scale_config.get_microservices_config();

            if ms_config.get("enabled", None) is False {
                console.print(
                    "Microservice mode is disabled (enabled = false in jac.toml).",
                    style="error"
                );
                return 1;
            }

            if not ms_config.get("routes", {}) {
                import from jac_scale.microservices.discovery { discover_sv_services }
                discovered = discover_sv_services(".");
                if discovered {
                    ms_config["routes"] = discovered;
                } else {
                    console.print(
                        "No microservices found: no routes in " "current directory.",
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
                import from jac_scale.microservices.orchestrator.orchestrator {
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

class JacScalePlugin {
    @hookimpl
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext {
        ctx = JScaleExecutionContext();
        if user_root is not None {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    @hookimpl
    static def create_server(
        jac_server: JacServer, host: str, port: int
    ) -> JFastApiServer {
        return JFastApiServer([]);
    }

    @hookimpl
    static def get_api_server_class -> type {
        return JacAPIServer;
    }

    @hookimpl
    static def get_user_manager(base_path: str) -> UserManager {
        return JacScaleUserManager(base_path=base_path);
    }

    @hookimpl
    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        import from .factories.storage_factory { StorageFactory }
        return StorageFactory.get_default(base_path, create_dirs);
    }

    @hookimpl
    static def ensure_sv_service(module_name: str, base_path: str) -> None {
        import os;
        import atexit;
        import subprocess;
        import from jaclang.runtimelib { sv_client }
        import from pathlib { Path }
        import from jac_scale.microservices.runtime.util {
            pick_free_port,
            resolve_jac_binary,
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
                import from jac_scale.config_loader { get_scale_config }
                import from jac_scale.targets.kubernetes.microservice.manifest_builder {
                    k8s_safe_name
                }
                import from jac_scale.microservices.runtime.util {
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

    @hookimpl
    static def get_sv_registry -> dict[str, str] {
        import os;
        import from jaclang.runtimelib { sv_client }

        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            return dict(sv_client._registry);
        }

        try {
            import from jac_scale.config_loader { get_scale_config }
            import from jac_scale.targets.kubernetes.microservice.runtime_resolver {
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

    @hookimpl
    static def sv_service_call(module_name: str, func_name: str, args: dict) -> any {
        import time;
        import from jaclang.runtimelib { sv_client }
        import from jaclang.runtimelib.sv_sse { consume_sse_stream }
        import from jac_scale.microservices.runtime.auth_ctx { get_current_auth }
        import from jac_scale.microservices.runtime.trace_ctx { get_current_trace }

        func_label = f"{module_name}.{func_name}";

        if module_name in sv_client._test_clients {
            tc = sv_client._test_clients[module_name];
            stream_cm = tc.stream("POST", f"/function/{func_name}", json=args);
            resp = stream_cm.__enter__();
            ct = resp.headers.get("content-type", "");
            if ct.startswith("text/event-stream") {
                return _wrap_sse_keepalive_scale(stream_cm, resp, None, func_label);
            }
            try {
                resp.read();
                data = resp.json();
            } finally {
                stream_cm.__exit__(None, None, None);
            }
            return _unwrap_sv_envelope(data, module_name, func_name);
        }

        if _breaker_should_skip(module_name) {
            raise RuntimeError(
                f"sv-to-sv RPC '{module_name}.{func_name}' blocked by " + f"open circuit breaker (cooldown {int(
                    _BREAKER_COOLDOWN_SECONDS
                )}s)"
            );
        }

        import jaclang;
        ms_registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
        url: str = ms_registry.get(module_name, "");
        if not url {
            url = sv_client.resolve_url(module_name);
        }
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
        import from jac_scale.microservices.runtime.tracing { current_traceparent }
        tp = current_traceparent(trace);
        if tp {
            headers["traceparent"] = tp;
        }

        max_attempts: int = 3;
        backoff: float = 0.1;
        last_err: Exception | None = None;

        rpc_timeout: float = _sv_rpc_timeout(module_name);

        for attempt in range(max_attempts) {
            try {
                client = httpx.Client(timeout=rpc_timeout);
                stream_cm = client.stream(
                    "POST", f"{url}/function/{func_name}", json=args, headers=headers
                );
                resp = stream_cm.__enter__();
                ct = resp.headers.get("content-type", "");
                if ct.startswith("text/event-stream") {
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
                last_err = e;
                if attempt < max_attempts - 1 {
                    time.sleep(backoff);
                    backoff = backoff * 2.0;
                }
            }
        }

        _breaker_record_failure(module_name);

        raise RuntimeError(
            f"sv-to-sv RPC '{module_name}.{func_name}' failed after " + f"{max_attempts} attempts: {last_err}"
        );
    }

    @hookimpl
    static def sv_walker_call(
        module_name: str, walker_name: str, args: dict, stub_cls: any
    ) -> any {
        import time;
        import from jaclang.runtimelib { sv_client }
        import from jac_scale.microservices.runtime.auth_ctx { get_current_auth }
        import from jac_scale.microservices.runtime.trace_ctx { get_current_trace }

        label = f"{module_name}.{walker_name}";

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
        import from jac_scale.microservices.runtime.tracing { current_traceparent }
        tp = current_traceparent(trace);
        if tp {
            headers["traceparent"] = tp;
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


def _wrap_sse_keepalive_scale(
    stream_cm: any, resp: any, client: any, func_label: str
) -> any {
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
        ;
    }
    return _SV_DEFAULT_RPC_TIMEOUT;
}


import from threading { Lock as _BreakerLock }
glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _breaker_state: dict[str, dict] = {},
     _breaker_lock = _BreakerLock();


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
            st["state"] = "HALF_OPEN";
            return False;
        }
        return False;
    }
}

def _breaker_record_success(provider: str) {
    with _breaker_lock {
        _breaker_state[provider] = {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
    }
}


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

def _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

def _breaker_peek(provider: str) -> dict | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

def _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}


def _unwrap_sv_envelope(data: any, module_name: str, func_name: str) -> any {
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


def _hydrate_walker_envelope(
    data: any, module_name: str, walker_name: str, stub_cls: any
) -> any {
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
