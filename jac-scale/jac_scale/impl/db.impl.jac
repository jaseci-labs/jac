"""Base Db implementation.

Every method raises NotImplementedError. Concrete behaviour lives in the
subclasses MongoDb (mongo_db.jac) and RedisDb (redis_db.jac), which override
the methods their backend supports. A method that is never overridden by a
given backend therefore falls through to these defaults and raises at runtime,
preserving the historical cross-backend contract (e.g. calling a Redis-only
method on a MongoDb handle raises NotImplementedError rather than silently
succeeding).
"""

# ===== PRIVATE HELPERS =====
impl Db._get_mongo_collection(col_name: str) -> Collection {
    raise NotImplementedError(
        "_get_mongo_collection() is not supported on this database backend."
    );
}

impl Db._get_redis_key(col_name: str, key: str) -> str {
    raise NotImplementedError(
        "_get_redis_key() is not supported on this database backend."
    );
}

# ===== COMMON METHODS =====
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

# ===== MONGODB-ONLY METHODS =====
impl Db.find_one(
    col_name: str, filter: dict, projection: dict | None = None
) -> dict | None {
    raise NotImplementedError("find_one() is a MongoDB-only operation.");
}

impl Db.find(
    col_name: str, filter: dict, projection: dict | None = None
) -> Cursor | list {
    raise NotImplementedError("find() is a MongoDB-only operation.");
}

impl Db.count_documents(col_name: str, filter: dict) -> int {
    raise NotImplementedError("count_documents() is a MongoDB-only operation.");
}

impl Db.create_index(
    col_name: str, keys: dict, unique: bool = False, name: str | None = None
) -> str {
    raise NotImplementedError("create_index() is a MongoDB-only operation.");
}

impl Db.insert_one(
    col_name: str, document: dict
) -> PyMongoInsertOneResult | InsertResult {
    raise NotImplementedError("insert_one() is a MongoDB-only operation.");
}

impl Db.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError("update_one() is a MongoDB-only operation.");
}

impl Db.delete_one(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError("delete_one() is a MongoDB-only operation.");
}

impl Db.insert_many(
    col_name: str, documents: list
) -> PyMongoInsertManyResult | InsertManyResult {
    raise NotImplementedError("insert_many() is a MongoDB-only operation.");
}

impl Db.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError("update_many() is a MongoDB-only operation.");
}

impl Db.delete_many(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError("delete_many() is a MongoDB-only operation.");
}

impl Db.find_by_id(col_name: str, id: str) -> dict | None {
    raise NotImplementedError("find_by_id() is a MongoDB-only operation.");
}

impl Db.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    raise NotImplementedError("update_by_id() is a MongoDB-only operation.");
}

impl Db.delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult {
    raise NotImplementedError("delete_by_id() is a MongoDB-only operation.");
}

impl Db.find_nodes(
    node_type: str, filter: dict = {}, col_name: str = '_anchors'
) -> list {
    raise NotImplementedError("find_nodes() is a MongoDB-only operation.");
}

# ===== REDIS-ONLY METHODS =====
impl Db.set_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    raise NotImplementedError("set_with_ttl() is a Redis-only operation.");
}

impl Db.incr(key: str, col_name: str = 'default') -> int {
    raise NotImplementedError("incr() is a Redis-only operation.");
}

impl Db.expire(key: str, seconds: int, col_name: str = 'default') -> bool {
    raise NotImplementedError("expire() is a Redis-only operation.");
}

impl Db.scan_keys(pattern: str, col_name: str = 'default') -> list[str] {
    raise NotImplementedError("scan_keys() is a Redis-only operation.");
}

impl Db.set_nx_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    raise NotImplementedError("set_nx_with_ttl() is a Redis-only operation.");
}

impl Db.delete_if_equals(
    key: str, expected_value: dict, col_name: str = 'default'
) -> bool {
    raise NotImplementedError("delete_if_equals() is a Redis-only operation.");
}

# ===== UTILITY =====
def get_db -> Db {
    # Local imports avoid a circular dependency: db.impl -> mongo_db -> db.
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}
