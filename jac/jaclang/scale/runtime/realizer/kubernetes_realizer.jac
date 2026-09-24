import os;
import pathlib;
import from dotenv { load_dotenv }
import from jaclang.cli.console { console }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.config.app_config { AppConfig, deployed_tree }
import from jaclang.scale.runtime.discovery.route_policy { format_route_origin_lines }

glob DELEGATED_ENV: str = "JAC_SCALE_PINNED_DEPLOY";


def pinned_deploy_argv(
    jac_bin: str,
    filename: str,
    target: str,
    pinned_version: str,
    enable_tls: bool = False
) -> list[str] {
    import from jaclang.scale.injector.binary { _ver_key }
    (major, minor, _) = _ver_key(pinned_version);
    if (major, minor) >= (0, 37) {
        argv = [jac_bin, "scale", "deploy", filename, "--target", target];
    } else {
        argv = [jac_bin, "start", filename, "--scale", "--target", target];
    }
    if enable_tls {
        argv.append("--enable-tls");
    }
    return argv;
}


obj KubernetesRealizer {
    has ms_config: dict[str, any];

    def _deploy_on_pinned_jac(
        filename: str, target: str, enable_tls: bool, dry_run: bool
    ) -> (int | None) {
        import subprocess;
        import from jaclang.scale.injector.binary {
            host_toolchain_path,
            resolve_deploy_version
        }
        import from jaclang.scale.injector.bundle { release_binary_env }
        import from jaclang.scale.config.dev_config { resolve_dev_channel }
        if dry_run or os.environ.get(DELEGATED_ENV) == "1" {
            return None;
        }
        project_dir = os.path.dirname(filename) or ".";
        pinned = host_toolchain_path(project_dir);
        if not pinned {
            return None;
        }
        pinned_version = resolve_deploy_version(
            project_dir, resolve_dev_channel(project_dir).value
        );
        console.print(
            "Deploying with the jac release this app pins, not the one "
            f"running this deploy ({pinned})."
        );
        env = release_binary_env();
        env[DELEGATED_ENV] = "1";
        code = subprocess.run(
            pinned_deploy_argv(pinned, filename, target, pinned_version, enable_tls),
            env=env
        ).returncode;
        if code != 0 {
            console.error(
                f"The deploy ran on the pinned jac ({pinned}) and exited {code}.",
                emoji=False
            );
        }
        return code;
    }

    def realize(
        filename: str,
        target: str = "kubernetes",
        enable_tls: bool = False,
        dry_run: bool = False,
        show_yaml: bool = False
    ) -> int {
        import from jaclang.scale.injector.binary { reset_deploy_version_cache }

        reset_deploy_version_cache();
        enabled = self.ms_config.get("enabled", None);
        ms_configured = get_scale_config().microservices_declared();

        if target == "kubernetes" {
            explicit_routes = dict(self.ms_config.get("routes", {}));
            merged_routes: dict[str, str] = {};
            if enabled is not False {
                if filename and os.path.exists(filename) {
                    import from jaclang.scale.runtime.discovery.discovery {
                        discover_sv_services
                    }
                    merged_routes = dict(discover_sv_services(filename));
                }
            }
            merged_routes.update(explicit_routes);
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
                    f"Deploying {len(merged_routes)} service{plural} behind a "
                    f"gateway{label}{hint}.",
                    style="cyan"
                );
                for line in format_route_origin_lines(merged_routes, explicit_routes) {
                    console.print(f"  {line}", style="muted");
                }
            } else {
                console.print(
                    "No [scale.microservices.routes] declared; deploying the app "
                    "as a single service behind a gateway.",
                    style="cyan"
                );
            }
        }
        if not os.path.exists(filename) {
            raise FileNotFoundError(f"File not found: '{filename}'");
        }
        delegated = self._deploy_on_pinned_jac(filename, target, enable_tls, dry_run);
        if delegated is not None {
            return delegated;
        }
        (code_folder, entry_file) = deployed_tree(filename);
        dotenv_path = os.path.join(code_folder, '.env');
        load_dotenv(dotenv_path);
        if dry_run {
            import from jaclang.scale.injector.binary { deploy_generation_refusal }
            refusal = deploy_generation_refusal(code_folder, offline=True);
            if refusal {
                console.error(refusal, emoji=False);
                return 2;
            }
        }
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
        deployment_target.secrets = scale_config.get_secrets_config();

        app_config = AppConfig(code_folder=code_folder, file_name=entry_file);
        console.warning(
            "Copying local source into the cluster via PVC and installing "
            "jac at pod startup. Keep secrets in [scale.secrets] "
            "(synced as a K8s Secret) or in .env, never inline in source."
        );
        if not ms_configured {
            console.warning(
                "Set [scale.microservices] in jac.toml to configure "
                "resources, scaling, ingress, and secrets before going to production."
            );
        }
        console.print("Preparing deployment...");

        if dry_run {
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
