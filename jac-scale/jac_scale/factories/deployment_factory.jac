"""Factory for creating deployment targets."""
import from typing { Any }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.base_config { BaseConfig }
import from jac_scale.abstractions.logger { Logger }

"""Factory for creating deployment target instances."""
class DeploymentTargetFactory {
    """Create a deployment target based on type.

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
        if target_type == 'kubernetes' {
            import from jac_scale.targets.kubernetes.kubernetes_target {
                KubernetesTarget
            }
            import from jac_scale.targets.kubernetes.kubernetes_config {
                KubernetesConfig
            }
            k8s_config = KubernetesConfig.from_dict(KubernetesConfig, config);
            return KubernetesTarget(config=k8s_config, logger=logger);
        } elif target_type == 'aws' {
            raise NotImplementedError("AWS target not yet implemented") ;
        } elif target_type == 'gcp' {
            raise NotImplementedError("GCP target not yet implemented") ;
        } else {
            raise ValueError(f"Unsupported deployment target type: {target_type}") ;
        }
    }
}
