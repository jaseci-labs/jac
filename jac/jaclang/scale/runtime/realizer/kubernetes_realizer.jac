import os;
import pathlib;
import from dotenv { load_dotenv }
import from jaclang.cli.console { console }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.discovery.route_policy { format_route_origin_lines }


obj KubernetesRealizer {
    has ms_config: dict[str, any];

    def realize(
        filename: str,
        target: str = "kubernetes",
        enable_tls: bool = False,
        dry_run: bool = False,
        show_yaml: bool = False
    ) -> int {
        enabled = self.ms_config.get("enabled", None);
        # Whether jac.toml genuinely declares [scale.microservices]. Resolved
        # up front: the "go set [scale.microservices]" guidance below must only
        # fire when the section is truly absent (issue #7434), and realize
        # itself writes merged routes back into the loaded config later.
        ms_configured = get_scale_config().microservices_declared();

        if target == "kubernetes" and enabled is not False {
            scale_discovered: dict[str, str] = {};
            if filename and os.path.exists(filename) {
                import from jaclang.scale.runtime.discovery.discovery {
                    discover_sv_services
                }
                scale_discovered = discover_sv_services(filename);
            }

            explicit_routes = dict(self.ms_config.get("routes", {}));
            merged_routes: dict[str, str] = dict(scale_discovered);
            merged_routes.update(explicit_routes);
            if (enabled is True) or merged_routes {
                target = "kubernetes-microservice";
                if merged_routes {
                    raw_cfg = get_scale_config().load();
                    raw_ms = raw_cfg.setdefault("microservices", {});
                    raw_ms["routes"] = merged_routes;
                    self.ms_config["routes"] = merged_routes;
                    plural = "s" if len(merged_routes) != 1 else "";
                    hint = (
                        ""
                            if ms_configured
                            else "; set [scale.microservices] in jac.toml to customize"
                    );
                    label = "" if ms_configured else " (auto-detected)";
                    console.print(
                        f"Microservice mode{label}: {len(merged_routes)} "
                        f"service{plural}. Deploying to kubernetes{hint}.",
                        style="cyan"
                    );
                    for line in format_route_origin_lines(
                        merged_routes, explicit_routes
                    ) {
                        console.print(f"  {line}", style="muted");
                    }
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
            target, target_config, logger, dry_run=dry_run
        );

        # --enable-tls issues certificates against the live cluster, so a dry
        # run has to skip it and fall through to the plan.
        if enable_tls and dry_run {
            console.warning(
                "--dry-run ignores --enable-tls: issuing certificates would "
                "modify the cluster. Re-run without --dry-run to enable TLS."
            );
        } elif enable_tls {
            if not target_config.get('domain', '') {
                raise ValueError(
                    "No domain configured. Set 'domain' under [scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            if not target_config.get('cert_manager_email', '') {
                raise ValueError(
                    "No cert_manager_email configured. Set 'cert_manager_email' under [scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            app_name = target_config.get('app_name', 'jaseci');
            deployment_target.enable_tls(app_name);
            return 0;
        }

        code_folder = os.path.relpath(code_folder);
        code_folder = pathlib.Path(code_folder).as_posix();
        base_file_path = os.path.basename(filename);
        deployment_target.secrets = scale_config.get_secrets_config();

        no_image = target == "kubernetes-microservice";
        app_config = AppConfig(
            code_folder=code_folder, file_name=base_file_path, no_image=no_image
        );
        if no_image {
            deployment_target.no_image = True;
            console.warning(
                "Copying local source into the cluster via PVC and installing "
                "jac at pod startup. Keep secrets in [scale.secrets] "
                "(synced as a K8s Secret) or in .env, never inline in source."
            );
            # Only nudge toward [scale.microservices] when it is genuinely
            # absent: telling a user to set a section they already set makes a
            # degraded-config failure indistinguishable from a healthy run.
            if not ms_configured {
                console.warning(
                    "Set [scale.microservices] in jac.toml to configure "
                    "resources, scaling, ingress, and secrets before going to production."
                );
            }
        }
        if target == "kubernetes-microservice" {
            console.print("Preparing microservice deployment...");
        } else {
            console.print("Installing Jaseci packages from PyPI...");
        }

        if dry_run {
            if target != "kubernetes-microservice" {
                console.warning(
                    f"--dry-run only supported with kubernetes-microservice target (got {target!r})."
                );
                return 1;
            }
            try {
                import from jaclang.scale.runtime.cli.plan { print_plan }
                import from jaclang.scale.runtime.cli.diagnostics { has_errors }
                (bundle, diagnostics) = print_plan(
                    deployment_target, app_config, show_yaml=show_yaml
                );
                exit_code = 2 if has_errors(diagnostics) else 0;
            } except Exception as e {
                console.error(f"--dry-run failed: {e}", emoji=False);
                return 1;
            }
            return exit_code;
        }

        try {
            result = deployment_target.deploy(app_config);
        } except Exception as e {
            console.error(f"Deployment failed: {e}", emoji=False);
            return 1;
        }
        if not result.success {
            console.error(
                f"Deployment failed: {result.message or 'unknown error'}", emoji=False
            );
            return 1;
        }
        if result.service_url {
            console.print(
                f"Deployment complete! Service available at: {result.service_url}"
            );
        }
        return 0;
    }
}
