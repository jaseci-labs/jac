import from typing { Any, Optional, Dict, cast }
import from jaclang.scale.deploy.database.database_provider { DatabaseProvider }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.config_loader { get_scale_config }
import from enum { StrEnum }

enum DatabaseType(StrEnum) { POSTGRES = 'postgres' }

def _resolve_uri(uri: (str | None), db_type: DatabaseType) -> str {
    if uri is not None {
        return uri;
    }
    db_config = get_scale_config().get_database_config();
    resolved = db_config.get('url') or db_config.get('postgres_url');
    if resolved is None {
        raise ValueError('Postgres URL not found in configuration');
    }
    return cast(str, resolved);
}

class DatabaseProviderFactory {
    static def create(
        provider_type: str,
        target: (DeploymentTarget | None) = None,
        config: (dict[str, any] | None) = None
    ) -> DatabaseProvider {
        if provider_type == 'kubernetes_postgres' {
            import from jaclang.scale.deploy.database.kubernetes_postgres {
                KubernetesPostgresProvider
            }
            return KubernetesPostgresProvider(target=target, config=config or {});
        } else {
            raise ValueError(f"Unsupported database provider type: {provider_type}");
        }
    }

    static def create_client(
        db_type: (DatabaseType | str),
        uri: Optional[str] = None,
        config: Optional[Dict[(str, Any)]] = None
    ) -> any {
        resolved_uri = _resolve_uri(uri, DatabaseType.POSTGRES);
        import from jaclang.runtimelib.session { conninfo_from_url }
        import from jaclang.runtimelib.store { PgStore }
        return PgStore(conninfo=conninfo_from_url(resolved_uri));
    }
}
