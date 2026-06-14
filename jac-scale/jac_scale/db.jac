"""Direct Database Access Module."""
import from jac_scale._optdeps.optional_deps { require_optional }
import from jac_scale._optdeps.pymongo { MongoClient }
import from jac_scale._optdeps.redis { Redis }
import from jac_scale.factories.database_factory {
    DatabaseProviderFactory,
    DatabaseType,
    _resolve_uri
}

glob _mongo_clients: dict[str, MongoClient] = {},
     _redis_clients: dict[str, Redis] = {};

# Result objects for database operations
obj InsertResult {
    has inserted_id: str;
}

obj InsertManyResult {
    has inserted_ids: list;
}

obj UpdateResult {
    has matched_count: int,
        modified_count: int,
        upserted_id: str | None = None;
}

obj DeleteResult {
    has deleted_count: int;
}

"""Get or create a pooled MongoDB client for the given URI."""
def get_mongo_client(uri: (str | None) = None) -> MongoClient {
    require_optional("pymongo", "data");
    global _mongo_clients;

    # Resolve URI from config if not provided
    resolved_uri = _resolve_uri(uri, DatabaseType.MONGODB);

    # Return existing client or create new one
    if resolved_uri not in _mongo_clients {
        _mongo_clients[resolved_uri] = DatabaseProviderFactory.create_client(
            DatabaseType.MONGODB, uri=resolved_uri
        );
    }

    return _mongo_clients[resolved_uri];
}

"""Get or create a pooled Redis client for the given URI."""
def get_redis_client(uri: (str | None) = None) -> Redis {
    require_optional("redis", "data");
    global _redis_clients;

    # Resolve URI from config if not provided
    resolved_uri = _resolve_uri(uri, DatabaseType.REDIS);

    # Return existing client or create new one
    if resolved_uri not in _redis_clients {
        _redis_clients[resolved_uri] = DatabaseProviderFactory.create_client(
            DatabaseType.REDIS, uri=resolved_uri
        );
    }

    return _redis_clients[resolved_uri];
}

"""Close a specific MongoDB client connection."""
def close_mongo_client(uri: (str | None) = None) {
    global _mongo_clients;

    # Resolve URI (silently skip if config not found)
    try {
        resolved_uri = _resolve_uri(uri, DatabaseType.MONGODB);
        if resolved_uri in _mongo_clients {
            _mongo_clients[resolved_uri].close();
            del _mongo_clients[resolved_uri];
        }
    } except ValueError { }
}

"""Close a specific Redis client connection."""
def close_redis_client(uri: (str | None) = None) {
    global _redis_clients;

    # Resolve URI (silently skip if config not found)
    try {
        resolved_uri = _resolve_uri(uri, DatabaseType.REDIS);
        if resolved_uri in _redis_clients {
            _redis_clients[resolved_uri].close();
            del _redis_clients[resolved_uri];
        }
    } except ValueError { }
}

"""Close all MongoDB and Redis connections."""
def close_all_db_connections {
    global _mongo_clients,_redis_clients;

    # Close all MongoDB clients
    for client in _mongo_clients.values() {
        try {
            client.close();
        } except Exception { }
    }
    _mongo_clients.clear();

    # Close all Redis clients
    for client in _redis_clients.values() {
        try {
            client.close();
        } except Exception { }
    }
    _redis_clients.clear();
}

obj Db {
    has client: (MongoClient | Redis),
        db_name: str = 'jac_db';

    def get(key: str, col_name: str = 'default') -> dict | None;
    def set(key: str, value: dict, col_name: str = 'default') -> str;
    def delete(key: str, col_name: str = 'default') -> int;
    def exists(key: str, col_name: str = 'default') -> bool;
}
