"""Direct Database Access Module."""
import from pymongo { MongoClient }
import from pymongo.results {
    InsertOneResult as PyMongoInsertOneResult,
    InsertManyResult as PyMongoInsertManyResult,
    UpdateResult as PyMongoUpdateResult,
    DeleteResult as PyMongoDeleteResult
}
import from pymongo.cursor { Cursor }
import from pymongo.collection { Collection }
import from redis { Redis }
import from jac_scale.factories.database_factory {
    DatabaseProviderFactory,
    DatabaseType,
    _resolve_uri
}
import from bson { ObjectId }
import from uuid { uuid4 }
import json;

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
def close_mongo_client(uri: (str | None) = None) -> None {
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
def close_redis_client(uri: (str | None) = None) -> None {
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
def close_all_db_connections -> None {
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

    # ===== PRIVATE HELPER METHODS =====
    """Get MongoDB collection reference."""
    def _get_mongo_collection(col_name: str) -> Collection;

    """Get namespaced Redis key."""
    def _get_redis_key(col_name: str, key: str) -> str;

    # ===== COMMON METHODS (work for both MongoDB and Redis) =====
    """Get a document/value by key.

    For MongoDB: key is the document ID.
    For Redis: key is the Redis key.
    """
    def get(key: str, col_name: str = 'default') -> dict | None;

    """Set a document/value by key.
    For MongoDB: Inserts or updates document with given ID.
    For Redis: Sets the key-value pair.
"""
    def set(key: str, value: dict, col_name: str = 'default') -> str;

    """Delete a document/value by key. Returns count deleted."""
    def delete(key: str, col_name: str = 'default') -> int;

    """Check if a key exists."""
    def exists(key: str, col_name: str = 'default') -> bool;

    # ===== MONGODB-ONLY METHODS =====
    """Find one document matching filter."""
    def find_one(col_name: str, filter: dict) -> dict | None;

    """Find all documents matching filter."""
    def find(col_name: str, filter: dict) -> Cursor | list;

    """Insert a single document."""
    def insert_one(
        col_name: str, document: dict
    ) -> PyMongoInsertOneResult | InsertResult;

    """Update one document."""
    def update_one(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult;

    """Delete one document."""
    def delete_one(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult;

    # Bulk operations
    def insert_many(
        col_name: str, documents: list
    ) -> PyMongoInsertManyResult | InsertManyResult;

    def update_many(
        col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult;

    def delete_many(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult;
    # ID-based convenience methods
    def find_by_id(col_name: str, id: str) -> dict | None;
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult;

    def delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult;
    # ===== REDIS-ONLY METHODS =====
    """Set a value with TTL/expiration.
    Args:
        key: Redis key
        value: Dictionary to store (JSON serialized)
        ttl: Time to live in seconds
        col_name: Optional namespace prefix
    """
    def set_with_ttl(
        key: str, value: dict, ttl: int, col_name: str = 'default'
    ) -> bool;

    """Increment a numeric key."""
    def incr(key: str, col_name: str = 'default') -> int;

    """Set expiration on existing key."""
    def expire(key: str, seconds: int, col_name: str = 'default') -> bool;

    """Get all keys matching pattern (Redis only).
    Warning: This uses SCAN which is safer than KEYS but still O(n).
    """
    def scan_keys(pattern: str, col_name: str = 'default') -> list[str];
}
