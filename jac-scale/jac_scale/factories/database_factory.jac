"""Factory for creating database providers."""
import from typing { Any }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import os;

enum DatabaseType { MONGODB = "mongodb", REDIS = "redis" }

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

    """Create a database client based on type and URI.

    This is for direct database access (not Kubernetes deployment).

    Args:
        db_type: Type of database ('mongodb' or 'redis')
        uri: Optional database URI. If not provided, will use environment variables or config
        config: Optional provider-specific configuration

    Returns:
        Database client instance (MongoClient or Redis)

    Raises:
        ValueError: If db_type is not supported
    """
    static def create_client(
        db_type: (DatabaseType | str),
        uri: (str | None) = None,
        config: (dict[str, Any] | None) = None
    ) -> Any {
        # Convert string to enum if needed
        if isinstance(db_type, str) {
            db_type = DatabaseType(db_type);
        }

        if db_type == DatabaseType.MONGODB {
            import from pymongo { MongoClient }
            import from jac_scale.config_loader { get_scale_config }
            # Priority: explicit URI > environment variable > config file
            if uri is None {
                scale_config = get_scale_config();
                db_config = scale_config.get_database_config();
                uri = db_config.get('mongodb_uri');
            }
            if uri is None {
                raise ValueError(
                    "MongoDB URI not provided. Specify via uri parameter, "
                    "MONGODB_URI environment variable, or jac.toml config."
                ) ;
            }
            return MongoClient(uri);
        } elif db_type == DatabaseType.REDIS {
            import from redis { Redis }
            import from jac_scale.config_loader { get_scale_config }
            # Priority: explicit URI > environment variable > config file
            if uri is None {
                scale_config = get_scale_config();
                db_config = scale_config.get_database_config();
                uri = db_config.get('redis_url');
            }
            if uri is None {
                raise ValueError(
                    "Redis URL not provided. Specify via uri parameter, "
                    "REDIS_URL environment variable, or jac.toml config."
                ) ;
            }
            return Redis.from_url(uri);
        } else {
            raise ValueError(f"Unsupported database type: {db_type}") ;
        }
    }
}
