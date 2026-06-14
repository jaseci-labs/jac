"""Base Db implementation: all methods raise NotImplementedError.

Per-backend behaviour lives in MongoDb (mongo_db.jac) and RedisDb (redis_db.jac).
"""

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

# ===== UTILITY =====
def get_db -> Db {
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.mongo_db { MongoDb }
    return MongoDb(client=get_mongo_client(), db_name='jac_db');
}
