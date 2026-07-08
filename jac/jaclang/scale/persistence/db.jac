import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale._optdeps.pymongo {
    MongoClient,
    PyMongoInsertOneResult,
    PyMongoInsertManyResult,
    PyMongoUpdateResult,
    PyMongoDeleteResult,
    Cursor,
    Collection
}
import from jaclang.scale._optdeps.redis { Redis }
import from jaclang.scale._optdeps.firestore { FirestoreClient }
import from jaclang.scale.deploy.database.factory {
    DatabaseProviderFactory,
    DatabaseType,
    _resolve_uri
}

glob _mongo_clients: dict[str, MongoClient] = {},
     _redis_clients: dict[str, Redis] = {},
     _firestore_clients: dict[str, FirestoreClient] = {};

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

def get_mongo_client(uri: (str | None) = None) -> MongoClient {
    require_optional("pymongo", "data.mongo");
    global _mongo_clients;

    resolved_uri = _resolve_uri(uri, DatabaseType.MONGODB);

    if resolved_uri not in _mongo_clients {
        _mongo_clients[resolved_uri] = DatabaseProviderFactory.create_client(
            DatabaseType.MONGODB, uri=resolved_uri
        );
    }

    return _mongo_clients[resolved_uri];
}

def get_redis_client(uri: (str | None) = None) -> Redis {
    require_optional("redis", "data.redis");
    global _redis_clients;

    resolved_uri = _resolve_uri(uri, DatabaseType.REDIS);

    if resolved_uri not in _redis_clients {
        _redis_clients[resolved_uri] = DatabaseProviderFactory.create_client(
            DatabaseType.REDIS, uri=resolved_uri
        );
    }

    return _redis_clients[resolved_uri];
}

def get_firestore_client(project_id: (str | None) = None) -> FirestoreClient {
    require_optional("google.cloud.firestore", "storage.firebase");
    global _firestore_clients;

    resolved_project_id = _resolve_uri(project_id, DatabaseType.FIRESTORE);

    if resolved_project_id not in _firestore_clients {
        _firestore_clients[resolved_project_id] = DatabaseProviderFactory.create_client(
            DatabaseType.FIRESTORE, uri=resolved_project_id
        );
    }

    return _firestore_clients[resolved_project_id];
}

def get_firestore_db(db_name: str = 'jac_db', project_id: (str | None) = None) -> Db;

def close_all_db_connections {
    global _mongo_clients,_redis_clients,_firestore_clients;

    for client in _mongo_clients.values() {
        try {
            client.close();
        } except Exception { }
    }
    _mongo_clients.clear();

    for client in _redis_clients.values() {
        try {
            client.close();
        } except Exception { }
    }
    _redis_clients.clear();

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

    def _get_mongo_collection(col_name: str) -> Collection abs;
    def _get_firestore_collection(col_name: str) -> any abs;
    def _get_redis_key(col_name: str, key: str) -> str abs;
    def get(key: str, col_name: str = 'default') -> dict | None abs;
    def set(key: str, value: dict, col_name: str = 'default') -> str abs;
    def delete(key: str, col_name: str = 'default') -> int abs;
    def exists(key: str, col_name: str = 'default') -> bool abs;
    def find_one(
        col_name: str, filter: dict, projection: dict | None = None
    ) -> dict | None abs;

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

    def find_by_id(col_name: str, id: str) -> dict | None abs;
    def update_by_id(
        col_name: str, id: str, update_data: dict, upsert_mode: bool = False
    ) -> PyMongoUpdateResult | UpdateResult abs;

    def delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult abs;
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
