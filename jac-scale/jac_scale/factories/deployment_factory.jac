"""Factory for creating deployment targets."""
import from jac_scale.engine.deployment_target { DeploymentTarget }
import from jac_scale.engine.config.base_config { DeploymentConfig }
import from jac_scale.engine.logger { Logger }

"""Factory for creating deployment targets."""
class DeploymentTargetFactory {
    """Create a deployment target based on type.
    
    Args:
        target_type: Type of target ('kubernetes', 'eks', etc.)
        config: Deployment configuration
        logger: Optional logger instance
        
    Returns:
        DeploymentTarget instance
    """
    static def create(
        target_type: str,
        config: DeploymentConfig,
        logger: (Logger | None) = None
    ) -> DeploymentTarget {
        if target_type == 'kubernetes' {
            import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
            return KubernetesTarget(config=config, logger=logger);
        } else {
            raise ValueError(f"Unknown target type: {target_type}. Currently only 'kubernetes' is supported.");
        }
    }
    
    """Create a deployment target from a config object."""
    static def from_config(config: DeploymentConfig) -> DeploymentTarget {
        return DeploymentTargetFactory.create(
            target_type=config.target_type,
            config=config
        );
    }
}

