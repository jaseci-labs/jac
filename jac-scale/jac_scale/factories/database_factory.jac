"""Factory for creating database providers."""
import from typing { Any, Optional, Dict, cast }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.config_loader { get_scale_config }
import from enum { StrEnum }

enum DatabaseType ( StrEnum ) { MONGODB = 'mongodb', REDIS = 'redis' }

"""Resolve database URI from parameter or configuration."""
def _resolve_uri(uri: (str | None), db_type: DatabaseType) -> str {
    if uri is not None {
        return uri;
    }

    db_config = get_scale_config().get_database_config();

    if db_type == DatabaseType.MONGODB {
        resolved = db_config.get('mongodb_uri');
        if resolved is None {
            raise ValueError('MongoDB URI not found in configuration') ;
        }
        return cast(str, resolved);
    } elif db_type == DatabaseType.REDIS {
        resolved = db_config.get('redis_url');
        if resolved is None {
            raise ValueError('Redis URL not found in configuration') ;
        }
        return cast(str, resolved);
    } else {
        raise ValueError(f'Unsupported database type: {db_type}') ;
    }
}

"""Factory for creating database provider instances."""
class DatabaseProviderFactory {
    """Create a database provider based on type."""
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

    static def create_client(
        db_type: (DatabaseType | str),
        uri: Optional[str] = None,
        config: Optional[Dict[(str, Any)]] = None
    ) -> Any {
        # Convert string to DatabaseType enum
        db_type_enum: DatabaseType;
        if (isinstance(db_type, str)) {
            try {
                db_type_enum = DatabaseType(db_type);
            } except Exception {
                raise ValueError(f"Invalid database type: {db_type}") ;
            }
        } else {
            db_type_enum = cast(DatabaseType, db_type);
        }

        # Resolve URI from config if not provided
        resolved_uri = _resolve_uri(uri, db_type_enum);

        # Create appropriate client
        if (db_type_enum == DatabaseType.MONGODB) {
            import from pymongo { MongoClient }
            return MongoClient(resolved_uri, **(config or {}));
        } elif (db_type_enum == DatabaseType.REDIS) {
            import from redis { Redis }
            return Redis.from_url(resolved_uri, **(config or {}));
        } else {
            raise ValueError(f"Unsupported database type: {db_type_enum}") ;
        }
    }
}
