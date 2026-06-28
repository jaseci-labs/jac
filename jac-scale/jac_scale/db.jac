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
import from jac_scale._optdeps.firestore { FirestoreClient }
import from jac_scale.factories.database_factory {
    DatabaseProviderFactory,
    DatabaseType,
    _resolve_uri
}

glob _mongo_clients: dict[str, MongoClient] = {},
     _redis_clients: dict[str, Redis] = {},
     _firestore_clients: dict[str, FirestoreClient] = {};

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

"""Get or create a pooled Firestore client for the given project ID."""
def get_firestore_client(project_id: (str | None) = None) -> FirestoreClient {
    require_optional("google.cloud.firestore", "firebase");
    global _firestore_clients;

    # Resolve project ID from config if not provided
    resolved_project_id = _resolve_uri(project_id, DatabaseType.FIRESTORE);

    # Return existing client or create new one
    if resolved_project_id not in _firestore_clients {
        _firestore_clients[resolved_project_id] = DatabaseProviderFactory.create_client(
            DatabaseType.FIRESTORE, uri=resolved_project_id
        );
    }

    return _firestore_clients[resolved_project_id];
}

"""Return a Firestore-backed Db using config/env project ID resolution."""
def get_firestore_db(db_name: str = 'jac_db', project_id: (str | None) = None) -> Db;

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

"""Close a specific Firestore client connection."""
def close_firestore_client(project_id: (str | None) = None) {
    global _firestore_clients;

    # Resolve project ID (silently skip if config not found)
    try {
        resolved_project_id = _resolve_uri(project_id, DatabaseType.FIRESTORE);
        if resolved_project_id in _firestore_clients {
            client = _firestore_clients[resolved_project_id];
            try {
                if hasattr(client, 'close') {
                    client.close();
                }
            } except Exception { }
            del _firestore_clients[resolved_project_id];
        }
    } except ValueError { }
}

"""Close all MongoDB, Redis, and Firestore connections."""
def close_all_db_connections {
    global _mongo_clients,_redis_clients,_firestore_clients;

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

    # Close all Firestore clients
    for client in _firestore_clients.values() {
        try {
            if hasattr(client, 'close') {
                client.close();
            }
        } except Exception { }
    }
    _firestore_clients.clear();
}

obj Db {
    has client: (MongoClient | Redis | FirestoreClient),
        db_name: str = 'jac_db',
        db_type: DatabaseType = DatabaseType.MONGODB;

    # Abstract cross-backend contract. Each method is `abs`; a concrete backend
    # (MongoDb, RedisDb, FirestoreDb) overrides the operations it supports.
    # Methods a backend does not override are not available on that handle --
    # Jac does not enforce abstract overrides at compile time, so an unsupported
    # call returns None.

    # ===== PRIVATE HELPER METHODS =====
    """Get MongoDB collection reference."""
    def _get_mongo_collection(col_name: str) -> Collection abs;

    """Get Firestore collection reference."""
    def _get_firestore_collection(col_name: str) -> any abs;

    """Get namespaced Redis key."""
    def _get_redis_key(col_name: str, key: str) -> str abs;

    # ===== COMMON METHODS (work for MongoDB, Firestore, and Redis) =====
    """Get a document/value by key.

    For MongoDB: key is the document ID.
    For Redis: key is the Redis key.
    """
    def get(key: str, col_name: str = 'default') -> dict | None abs;

    """Set a document/value by key.
    For MongoDB: Inserts or updates document with given ID.
    For Redis: Sets the key-value pair.
"""
    def set(key: str, value: dict, col_name: str = 'default') -> str abs;

    """Delete a document/value by key. Returns the number of documents deleted."""
    def delete(key: str, col_name: str = 'default') -> int abs;

    """Check if a key exists."""
    def exists(key: str, col_name: str = 'default') -> bool abs;

    # ===== DOCUMENT-STORE METHODS =====
    """Find one document matching filter.

    `projection` follows the same pymongo semantics as `find` (see below),
    including the Firestore-specific notes.
    """
    def find_one(
        col_name: str, filter: dict, projection: dict | None = None
    ) -> dict | None abs;

    """Find all documents matching filter.

    `projection` follows pymongo semantics: `{field: 1}` to include, `{field: 0}`
    to exclude. Passing None returns all fields. Mixing include and exclude
    (other than suppressing `_id`) raises ValueError.

    For Firestore, inclusion projections push down to the server via
    `query.select()` (fewer fields over the wire); exclusion projections have no
    server-side equivalent, so the full document is read and the listed fields
    are stripped client-side. Either way the returned shape matches MongoDB.

    Pass `limit` to cap the number of results. For Firestore this is important:
    the backend materializes results into a list, so an unbounded find streams
    the entire matching set into memory (and bills a read per document). For
    MongoDB the result is a lazy cursor, so `limit` is applied to the cursor.
    """
    def find(
        col_name: str,
        filter: dict,
        projection: dict | None = None,
        limit: int | None = None
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
    # ID-based convenience methods
    def find_by_id(col_name: str, id: str) -> dict | None abs;
    """Update a document by ID.

    Note: Firestore requires a read before write to distinguish update from
    upsert, so each call incurs one billed read plus one write."""
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult abs;

    """Delete a document by ID. Returns the number of documents deleted."""
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
        node_type: str, filter: dict = None, col_name: str = '_anchors'
    ) -> list abs;
}
