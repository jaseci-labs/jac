import from typing { Any, Optional, Dict, cast }
import from jaclang.scale.deploy.database.database_provider { DatabaseProvider }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from enum { StrEnum }

enum DatabaseType(StrEnum) {
    MONGODB = 'mongodb',
    REDIS = 'redis',
    FIRESTORE = 'firestore'
}

def _resolve_uri(uri: (str | None), db_type: DatabaseType) -> str {
    if uri is not None {
        return uri;
    }

    db_config = get_scale_config().get_database_config();

    if db_type == DatabaseType.MONGODB {
        resolved = db_config.get('mongodb_uri');
        if resolved is None {
            raise ValueError('MongoDB URI not found in configuration');
        }
        return cast(str, resolved);
    } elif db_type == DatabaseType.REDIS {
        resolved = db_config.get('redis_url');
        if resolved is None {
            raise ValueError('Redis URL not found in configuration');
        }
        return cast(str, resolved);
    } elif db_type == DatabaseType.FIRESTORE {
        resolved = db_config.get('project_id');
        if resolved is None {
            raise ValueError('Firestore project ID not found in configuration');
        }
        return cast(str, resolved);
    } else {
        raise ValueError(f'Unsupported database type: {db_type}');
    }
}

class DatabaseProviderFactory {
    static def create(
        provider_type: str,
        target: (DeploymentTarget | None) = None,
        config: (dict[str, any] | None) = None
    ) -> DatabaseProvider {
        if provider_type == 'kubernetes_mongo' {
            import from jaclang.scale.deploy.database.kubernetes_mongo {
                KubernetesMongoProvider
            }
            return KubernetesMongoProvider(target=target, config=config or {});
        } elif provider_type == 'kubernetes_redis' {
            import from jaclang.scale.deploy.database.kubernetes_redis {
                KubernetesRedisProvider
            }
            return KubernetesRedisProvider(target=target, config=config or {});
        } elif provider_type == 'aws_documentdb' {
            raise NotImplementedError("AWS DocumentDB provider not yet implemented");
        } else {
            raise ValueError(f"Unsupported database provider type: {provider_type}");
        }
    }

    static def create_client(
        db_type: (DatabaseType | str),
        uri: Optional[str] = None,
        config: Optional[Dict[(str, Any)]] = None
    ) -> any {
        db_type_enum: DatabaseType;
        if (isinstance(db_type, str)) {
            try {
                db_type_enum = DatabaseType(db_type);
            } except Exception {
                raise ValueError(f"Invalid database type: {db_type}");
            }
        } else {
            db_type_enum = cast(DatabaseType, db_type);
        }

        resolved_uri = _resolve_uri(uri, db_type_enum);

        if (db_type_enum == DatabaseType.MONGODB) {
            require_optional("pymongo", "data.mongo");
            import from pymongo { MongoClient }
            return MongoClient(resolved_uri, **(config or {}));
        } elif (db_type_enum == DatabaseType.REDIS) {
            require_optional("redis", "data.redis");
            import from redis { Redis }
            return Redis.from_url(resolved_uri, **(config or {}));
        } elif (db_type_enum == DatabaseType.FIRESTORE) {
            require_optional("google.cloud.firestore", "storage.firebase");
            import from jaclang.scale._optdeps.firestore { FirestoreClient }
            return FirestoreClient(project=resolved_uri, **(config or {}));
        } else {
            raise ValueError(f"Unsupported database type: {db_type_enum}");
        }
    }
}
