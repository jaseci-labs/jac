"""KubernetesRealizer: deploy an app to a cluster per the RealizationPlan.

The `--scale` path hands control here. The realizer owns target selection (zero-
config auto-detect of the microservice topology), config load, --enable-tls,
--dry-run, and the deploy itself, setting the hook's cancel/return data. This is
the cluster sibling of LocalRealizer, so the pre-hook never branches on the deploy
details itself.
"""

import os;
import pathlib;
import from dotenv { load_dotenv }
import from jaclang.cli.command { HookContext }
import from jaclang.cli.console { console }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.observability.factory { UtilityFactory }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.abstractions.config.app_config { AppConfig }


"""Serves the `--scale` deploy. `ms_config` is the resolved
[plugins.scale.microservices] table (routes may be pre-declared)."""
obj KubernetesRealizer {
    has ms_config: dict[str, any];

    """Run the deploy. Reads args off `context` and sets cancel/return data on it
    exactly as the deploy flow requires."""
    def realize(context: HookContext) -> None {
        enabled = self.ms_config.get("enabled", None);
        filename = context.get_arg("filename");
        target = context.get_arg("target", "kubernetes");
        # Zero-config: pick the microservice target when opted in (enabled=true)
        # or auto-detected sv services. enabled=false stays a monolith deploy.
        if target == "kubernetes" and enabled is not False {
            scale_discovered: dict[str, str] = {};
            needs_discovery = (enabled is None)
            or (enabled is True and not self.ms_config.get("routes", {}));
            if needs_discovery and filename and os.path.exists(filename) {
                import from jac_scale.runtime.discovery.discovery { discover_sv_services }
                scale_discovered = discover_sv_services(filename);
            }
            if (enabled is True) or scale_discovered {
                target = "kubernetes-microservice";
                if scale_discovered and not self.ms_config.get("routes", {}) {
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
                        f"kubernetes; set [plugins.scale.microservices] to customize.",
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
        # kubernetes-microservice shares the [plugins.scale.kubernetes] config
        # shape with the monolith target (same knobs, different deploy strategy).
        if target in ('kubernetes', 'kubernetes-microservice') {
            target_config = scale_config.get_kubernetes_config();
        } else {
            target_config = scale_config.get_section(target);
        }
        deployment_target = DeploymentTargetFactory.create(
            target, target_config, logger
        );

        # --enable-tls: patch TLS on the live deployment (no redeploy).
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

        code_folder = os.path.relpath(code_folder);
        code_folder = pathlib.Path(code_folder).as_posix();
        base_file_path = os.path.basename(filename);
        deployment_target.secrets = scale_config.get_secrets_config();
        # PVC injection is the only code-shipping path; always enabled.
        no_image = target == "kubernetes-microservice";
        app_config = AppConfig(
            code_folder=code_folder,
            file_name=base_file_path,
            no_image=no_image
        );
        if no_image {
            deployment_target.no_image = True;
            console.warning(
                "Copying local source into the cluster via PVC and installing "
                "jac at pod startup. Keep secrets in [plugins.scale.secrets] "
                "(synced as a K8s Secret) or in .env, never inline in source."
            );
            console.warning(
                "Set [plugins.scale.microservices] in jac.toml to configure "
                "resources, scaling, ingress, and secrets before going to production."
            );
        }
        if target == "kubernetes-microservice" {
            console.print("Preparing microservice deployment...");
        } else {
            console.print("Installing Jaseci packages from PyPI...");
        }
        # --dry-run cancels execution before the deploy.
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
                import from jac_scale.runtime.cli.plan { print_plan }
                import from jac_scale.runtime.cli.diagnostics { has_errors }
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

        # Deploy. Cancel execution on failure so we don't fall through to the
        # local-mode dev server (which would mask the K8s deploy error).
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
