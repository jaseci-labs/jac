"""Base Db implementation: all methods raise NotImplementedError.

Per-backend behaviour lives in MongoDb (mongo_db.jac) and RedisDb (redis_db.jac).
"""

"""Check if a collection is read-only (protected from user modifications)."""
def _is_read_only_collection(col_name: str) -> bool {
    return col_name == '_anchors';
}

"""Validate that a collection is not read-only, raise error if it is."""
def _validate_not_read_only(col_name: str) {
    if _is_read_only_collection(col_name) {
        raise PermissionError(
            f"Collection '{col_name}' is read-only and cannot be modified. "
            "This is a system collection managed internally."
        );
    }
}

impl Db.get(key: str, col_name: str = 'default') -> dict | None {
    raise NotImplementedError("get() is not implemented for this database backend.");
}

impl Db.set(key: str, value: dict, col_name: str = 'default') -> str {
    raise NotImplementedError("set() is not implemented for this database backend.");
}

impl Db.delete(key: str, col_name: str = 'default') -> int {
    raise NotImplementedError("delete() is not implemented for this database backend.");
}

impl Db.exists(key: str, col_name: str = 'default') -> bool {
    raise NotImplementedError("exists() is not implemented for this database backend.");
}

impl Db.find_one(
    col_name: str, filter: dict, projection: dict | None = None
) -> dict | None {
    raise NotImplementedError(
        "find_one() is not implemented for this database backend."
    );
}

impl Db.find(
    col_name: str, filter: dict, projection: dict | None = None
) -> Cursor | list {
    raise NotImplementedError("find() is not implemented for this database backend.");
}

impl Db.count_documents(col_name: str, filter: dict) -> int {
    raise NotImplementedError(
        "count_documents() is not implemented for this database backend."
    );
}

impl Db.create_index(
    col_name: str, keys: dict, unique: bool = False, name: str | None = None
) -> str {
    raise NotImplementedError(
        "create_index() is not implemented for this database backend."
    );
}

impl Db.insert_one(
    col_name: str, document: dict
) -> PyMongoInsertOneResult | InsertResult {
    raise NotImplementedError(
        "insert_one() is not implemented for this database backend."
    );
}

impl Db.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError(
        "update_one() is not implemented for this database backend."
    );
}

impl Db.delete_one(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError(
        "delete_one() is not implemented for this database backend."
    );
}

impl Db.insert_many(
    col_name: str, documents: list
) -> PyMongoInsertManyResult | InsertManyResult {
    raise NotImplementedError(
        "insert_many() is not implemented for this database backend."
    );
}

impl Db.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError(
        "update_many() is not implemented for this database backend."
    );
}

impl Db.delete_many(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError(
        "delete_many() is not implemented for this database backend."
    );
}

impl Db.find_by_id(col_name: str, id: str) -> dict | None {
    raise NotImplementedError(
        "find_by_id() is not implemented for this database backend."
    );
}

impl Db.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError(
        "update_by_id() is not implemented for this database backend."
    );
}

impl Db.delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError(
        "delete_by_id() is not implemented for this database backend."
    );
}

impl Db.set_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    raise NotImplementedError(
        "set_with_ttl() is not supported for MongoDB. "
        "MongoDB uses TTL indexes, not per-key expiration."
    );
}

impl Db.incr(key: str, col_name: str = 'default') -> int {
    raise NotImplementedError(
        "incr() is not supported for MongoDB. "
        "Use update_one() with $inc operator instead."
    );
}

impl Db.expire(key: str, seconds: int, col_name: str = 'default') -> bool {
    raise NotImplementedError(
        "expire() is not supported for MongoDB. "
        "MongoDB uses TTL indexes for document expiration."
    );
}

impl Db.set_nx_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    raise NotImplementedError(
        "set_nx_with_ttl() is not supported for MongoDB. "
        "Use Redis for distributed-lock semantics."
    );
}

impl Db.delete_if_equals(
    key: str, expected_value: dict, col_name: str = 'default'
) -> bool {
    raise NotImplementedError("delete_if_equals() is not supported for MongoDB.");
}

impl Db.scan_keys(pattern: str, col_name: str = 'default') -> list[str] {
    raise NotImplementedError(
        "scan_keys() is not supported for MongoDB. " "Use find() with filters instead."
    );
}

impl Db.find_nodes(
    node_type: str, filter: dict = {}, col_name: str = '_anchors'
) -> list {
    raise NotImplementedError(
        "find_nodes() is not implemented for this database backend."
    );
}

# ===== UTILITY =====
def get_db -> Db {
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}
