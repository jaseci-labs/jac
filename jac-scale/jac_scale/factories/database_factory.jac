"""Factory for creating database providers."""
import from typing { Any }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }

"""Factory for creating database provider instances."""
class DatabaseProviderFactory {
    """Create a database provider based on type.

    Args:
        provider_type: Type of database provider ('kubernetes_mongo', 'kubernetes_redis', etc.)
        target: Deployment target instance (for target-specific providers)
        config: Optional provider-specific configuration

    Returns:
        DatabaseProvider instance

    Raises:
        ValueError: If provider_type is not supported
        NotImplementedError: If provider is not yet implemented
    """
    static def create(
        provider_type: str,
        target: (DeploymentTarget | None) = None,
        config: (dict[str, Any] | None) = None
    ) -> DatabaseProvider {
        if provider_type == 'kubernetes_mongo' {
            import from jac_scale.providers.database.kubernetes_mongo {
                KubernetesMongoProvider
            }
            return KubernetesMongoProvider(target=target, config=config or {});
        } elif provider_type == 'kubernetes_redis' {
            import from jac_scale.providers.database.kubernetes_redis {
                KubernetesRedisProvider
            }
            return KubernetesRedisProvider(target=target, config=config or {});
        } elif provider_type == 'aws_documentdb' {
            raise NotImplementedError("AWS DocumentDB provider not yet implemented") ;
        } else {
            raise ValueError(f"Unsupported database provider type: {provider_type}") ;
        }
    }
}
