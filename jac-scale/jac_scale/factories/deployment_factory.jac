import from typing { Callable }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.base_config { BaseConfig }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale._optdeps.optional_deps { require_optional }

"""Type alias for target factory callables.""" type TargetFactory = Callable[
    [dict[str, any], Logger | None],
    DeploymentTarget
];


class DeploymentTargetFactory {
    static has _registry: dict[str, TargetFactory] = {};

    static def register(target_type: str, factory: TargetFactory) {
        DeploymentTargetFactory._registry[target_type] = factory;
    }

    static def create(
        target_type: str, config: dict[str, any], logger: (Logger | None) = None
    ) -> DeploymentTarget {
        if target_type in DeploymentTargetFactory._registry {
            factory = DeploymentTargetFactory._registry[target_type];
            return factory(config, logger);
        }
        if target_type == 'kubernetes' {
            require_optional("kubernetes", "deploy");
            import from jac_scale.targets.kubernetes.kubernetes_target {
                KubernetesTarget
            }
            import from jac_scale.targets.kubernetes.kubernetes_config {
                KubernetesConfig
            }
            k8s_config = KubernetesConfig.from_dict(KubernetesConfig, config);
            return KubernetesTarget(config=k8s_config, logger=logger);
        } elif target_type == 'kubernetes-microservice' {
            require_optional("kubernetes", "deploy");
            import from jac_scale.targets.kubernetes.kubernetes_config {
                KubernetesConfig
            }
            import from jac_scale.targets.kubernetes.microservice.target {
                KubernetesMicroserviceTarget
            }
            k8s_config = KubernetesConfig.from_dict(KubernetesConfig, config);
            return KubernetesMicroserviceTarget(config=k8s_config, logger=logger);
        } elif target_type == 'aws' {
            raise NotImplementedError("AWS target not yet implemented");
        } elif target_type == 'gcp' {
            raise NotImplementedError("GCP target not yet implemented");
        } else {
            raise ValueError(f"Unsupported deployment target type: {target_type}");
        }
    }
}
