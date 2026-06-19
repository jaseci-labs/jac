"""Direct Database Access Module."""
import from jac_scale._optdeps.optional_deps { require_optional }
import from jac_scale._optdeps.pymongo {
    MongoClient,
    PyMongoInsertOneResult,
    PyMongoInsertManyResult,
    PyMongoUpdateResult,
    PyMongoDeleteResult,
    Cursor,
    Collection
}
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
        db_name: str = 'jac_db',
        db_type: DatabaseType = DatabaseType.MONGODB;

    # Abstract cross-backend contract. Each method is `abs`; a concrete backend
    # (MongoDb, RedisDb) overrides the operations it supports. Methods a backend
    # does not override are not available on that handle -- Jac does not enforce
    # abstract overrides at compile time, so an unsupported call returns None.

    # ===== PRIVATE HELPER METHODS =====
    """Get MongoDB collection reference."""
    def _get_mongo_collection(col_name: str) -> Collection abs;

    """Get namespaced Redis key."""
    def _get_redis_key(col_name: str, key: str) -> str abs;

    # ===== COMMON METHODS (work for both MongoDB and Redis) =====
    def get(key: str, col_name: str = 'default') -> dict | None abs;
    def set(key: str, value: dict, col_name: str = 'default') -> str abs;
    def delete(key: str, col_name: str = 'default') -> int abs;
    def exists(key: str, col_name: str = 'default') -> bool abs;
    # ===== MONGODB-ONLY METHODS =====
    def find_one(
        col_name: str, filter: dict, projection: dict | None = None
    ) -> dict | None abs;

    def find(
        col_name: str, filter: dict, projection: dict | None = None
    ) -> Cursor | list abs;

    def count_documents(col_name: str, filter: dict) -> int abs;
    def create_index(
        col_name: str, keys: dict, unique: bool = False, name: str | None = None
    ) -> str abs;

    def insert_one(
        col_name: str, document: dict
    ) -> PyMongoInsertOneResult | InsertResult abs;

    def update_one(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult abs;

    def delete_one(
        col_name: str, filter: dict
    ) -> PyMongoDeleteResult | DeleteResult abs;

    def insert_many(
        col_name: str, documents: list
    ) -> PyMongoInsertManyResult | InsertManyResult abs;

    def update_many(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult abs;

    def delete_many(
        col_name: str, filter: dict
    ) -> PyMongoDeleteResult | DeleteResult abs;
    # find_by_id/delete_by_id are also implemented by RedisDb; update_by_id is MongoDB-only.
    def find_by_id(col_name: str, id: str) -> dict | None abs;
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult abs;

    def delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult abs;
    # ===== REDIS-ONLY METHODS =====
    def set_with_ttl(
        key: str, value: dict, ttl: int, col_name: str = 'default'
    ) -> bool abs;

    def incr(key: str, col_name: str = 'default') -> int abs;
    def expire(key: str, seconds: int, col_name: str = 'default') -> bool abs;
    def scan_keys(pattern: str, col_name: str = 'default') -> list[str] abs;
    def set_nx_with_ttl(
        key: str, value: dict, ttl: int, col_name: str = 'default'
    ) -> bool abs;

    def delete_if_equals(
        key: str, expected_value: dict, col_name: str = 'default'
    ) -> bool abs;

    def find_nodes(
        node_type: str, filter: dict = {}, col_name: str = '_anchors'
    ) -> list abs;
}
