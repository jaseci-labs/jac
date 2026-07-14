import from typing { Callable }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.base_config { BaseConfig }
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.project.capabilities {
    ensure_global_capability,
    missing_capability_dists
}

type TargetFactory = Callable[[dict[str, any], Logger | None], DeploymentTarget];

"""Deploy tooling is operator-machine tooling pinned by the jac binary, not a
project dependency -- sync it into the jac global site on first use so a scale
deploy never requires a manual 'jac install --scale'.

A dry run renders manifests and applies nothing, so it must not reach for the
tooling at all: installing into the global site is a mutation of the operator's
machine, and --dry-run promises not to make any."""
def _ensure_deploy_tooling(dry_run: bool = False) {
    if dry_run {
        return;
    }
    missing = missing_capability_dists("deploy.k8s");
    if not missing {
        return;
    }
    import from jaclang.cli.console { console }
    console.print(
        f"Deploy tooling missing; installing {', '.join(missing)} "
        f"(capability 'deploy.k8s') into the jac global site."
    );
    if not ensure_global_capability("deploy.k8s") {
        console.warning(
            "Automatic install of the deploy tooling failed; run "
            "'jac install --scale' to see the full pip output."
        );
    }
}

"""Gate the k8s client behind the deploy path only. Manifest rendering is pure
dict-building, so a dry run stays useful on a machine that has never installed
the deploy tooling."""
def _require_deploy_tooling(dry_run: bool = False) {
    if dry_run {
        return;
    }
    require_optional("kubernetes", "deploy.k8s");
}

class DeploymentTargetFactory {
    static has _registry: dict[str, TargetFactory] = {};

    static def register(target_type: str, factory: TargetFactory) {
        DeploymentTargetFactory._registry[target_type] = factory;
    }

    static def create(
        target_type: str,
        config: dict[str, any],
        logger: (Logger | None) = None,
        dry_run: bool = False
    ) -> DeploymentTarget {
        if target_type in DeploymentTargetFactory._registry {
            factory = DeploymentTargetFactory._registry[target_type];
            return factory(config, logger);
        }

        if target_type == 'kubernetes' {
            _ensure_deploy_tooling(dry_run);
            _require_deploy_tooling(dry_run);
            import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
                KubernetesTarget
            }
            import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
                KubernetesConfig
            }
            k8s_config = KubernetesConfig.from_dict(KubernetesConfig, config);
            return KubernetesTarget(config=k8s_config, logger=logger, dry_run=dry_run);
        } elif target_type == 'kubernetes-microservice' {
            _ensure_deploy_tooling(dry_run);
            _require_deploy_tooling(dry_run);
            import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
                KubernetesConfig
            }
            import from jaclang.scale.deploy.target.kubernetes.microservice.target {
                KubernetesMicroserviceTarget
            }
            k8s_config = KubernetesConfig.from_dict(KubernetesConfig, config);
            return KubernetesMicroserviceTarget(
                config=k8s_config, logger=logger, dry_run=dry_run
            );
        } elif target_type == 'aws' {
            raise NotImplementedError("AWS target not yet implemented");
        } elif target_type == 'gcp' {
            raise NotImplementedError("GCP target not yet implemented");
        } else {
            raise ValueError(f"Unsupported deployment target type: {target_type}");
        }
    }
}
