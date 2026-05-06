"""Factory for creating deployment targets.

Supports both built-in targets (kubernetes) and plugin-registered targets.
External packages can register custom targets via DeploymentTargetFactory.register().
"""
import from typing { Any, Callable }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.base_config { BaseConfig }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale._optdeps.optional_deps { require_optional }

"""Type alias for target factory callables.""" type TargetFactory = Callable[
    [dict[str, Any], Logger | None],
    DeploymentTarget
];

"""Factory for creating deployment target instances.

Maintains a registry of target factories that can be extended by external
plugins. Built-in targets (kubernetes) are always available. Custom targets
are checked first, allowing plugins to override built-in behavior.

Example:
    # Register a custom target from an external plugin
    DeploymentTargetFactory.register(
        "enterprise-kubernetes",
        lambda config, logger: MyTarget(config=config, logger=logger)
    )

    # Create the target via the standard factory
    target = DeploymentTargetFactory.create("enterprise-kubernetes", config)
"""
class DeploymentTargetFactory {
    static has _registry: dict[str, TargetFactory] = {};

    """Register a custom deployment target factory.

    Args:
        target_type: Unique name for the target (e.g. 'enterprise-kubernetes')
        factory: Callable that accepts (config: dict, logger: Logger | None)
                 and returns a DeploymentTarget instance
    """
    static def register(target_type: str, factory: TargetFactory) {
        DeploymentTargetFactory._registry[target_type] = factory;
    }

    """Create a deployment target based on type.

    Checks the plugin registry first, then falls back to built-in targets.

    Args:
        target_type: Type of deployment target ('kubernetes', 'aws', 'gcp', etc.)
        config: Configuration dictionary
        logger: Optional logger instance

    Returns:
        DeploymentTarget instance

    Raises:
        ValueError: If target_type is not supported
        NotImplementedError: If target is not yet implemented
    """
    static def create(
        target_type: str, config: dict[str, Any], logger: (Logger | None) = None
    ) -> DeploymentTarget {
        # Check plugin registry first
        if target_type in DeploymentTargetFactory._registry {
            factory = DeploymentTargetFactory._registry[target_type];
            return factory(config, logger);
        }
        # Built-in targets
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
        } elif target_type == 'aws' {
            raise NotImplementedError("AWS target not yet implemented");
        } elif target_type == 'gcp' {
            raise NotImplementedError("GCP target not yet implemented");
        } else {
            raise ValueError(f"Unsupported deployment target type: {target_type}");
        }
    }
}
