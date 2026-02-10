"""Database implementation with proper separation of MongoDB and Redis semantics.

MongoDB: Document-based operations with filters and queries.
Redis: Pure key-value operations with Redis-native features (TTL, INCR, etc.).
"""

# ===== HELPER FUNCTIONS =====
"""Generate Redis key in format: {db_name}:{col_name}:{key}."""
def _redis_key(db_name: str, col_name: str, key: str) -> str {
    return f"{db_name}:{col_name}:{key}";
}

"""Apply MongoDB-style update operations to a document."""
def _apply_update(doc: dict, update_data: dict) -> dict {
    if '$set' in update_data {
        doc.update(update_data['$set']);
    } else {
        doc.update(update_data);
    }
    return doc;
}

# ===== HELPER METHOD IMPLEMENTATIONS =====
"""Get MongoDB collection reference."""
impl Db._get_mongo_collection(col_name: str) -> Collection {
    return self.client[self.db_name][col_name];
}

"""Get namespaced Redis key."""
impl Db._get_redis_key(col_name: str, key: str) -> str {
    return _redis_key(self.db_name, col_name, key);
}

# ===== COMMON METHODS (work for both) =====
impl Db.get(
    key: str, col_name: str = 'default'
) -> dict | None {
    if self.db_type == DatabaseType.MONGODB {
        # Try string key first, then ObjectId if valid
        result = self._get_mongo_collection(col_name).find_one({'_id': key});
        if result is None {
            try {
                result = self._get_mongo_collection(col_name).find_one(
                    {'_id': ObjectId(key)}
                );
            } except Exception { }
        }
        return result;
    } elif self.db_type == DatabaseType.REDIS {
        redis_key = self._get_redis_key(col_name, key);
        if (data := self.client.get(redis_key)) {
            return json.loads(data);
        }
        return None;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.set(key: str, value: dict, col_name: str = 'default') -> str {
    if self.db_type == DatabaseType.MONGODB {
        col = self._get_mongo_collection(col_name);
        # Upsert: update if exists, insert if not
        value_copy = value.copy();
        # Use string key directly as _id (MongoDB supports string _id)
        value_copy['_id'] = key;
        col.replace_one({'_id': key}, value_copy, upsert=True);
        return key;
    } elif self.db_type == DatabaseType.REDIS {
        redis_key = self._get_redis_key(col_name, key);
        self.client.set(redis_key, json.dumps(value));
        return key;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.delete(key: str, col_name: str = 'default') -> int {
    if self.db_type == DatabaseType.MONGODB {
        # Try string key first, then ObjectId if valid
        result = self._get_mongo_collection(col_name).delete_one({'_id': key});
        if result.deleted_count == 0 {
            try {
                result = self._get_mongo_collection(col_name).delete_one(
                    {'_id': ObjectId(key)}
                );
            } except Exception { }
        }
        return result.deleted_count;
    } elif self.db_type == DatabaseType.REDIS {
        return self.client.delete(self._get_redis_key(col_name, key));
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.exists(key: str, col_name: str = 'default') -> bool {
    if self.db_type == DatabaseType.MONGODB {
        # Try string key first, then ObjectId if valid
        exists = self._get_mongo_collection(col_name).count_documents(
            {'_id': key}, limit=1
        ) > 0;
        if not exists {
            try {
                exists = self._get_mongo_collection(col_name).count_documents(
                    {'_id': ObjectId(key)}, limit=1
                ) > 0;
            } except Exception { }
        }
        return exists;
    } elif self.db_type == DatabaseType.REDIS {
        return self.client.exists(self._get_redis_key(col_name, key)) > 0;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

# ===== MONGODB-ONLY METHODS =====
impl Db.find_one(
    col_name: str, filter: dict
) -> dict | None {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "find_one() with filters is not supported for Redis. "
            "Redis is a key-value store. Use get(key) instead."
        ) ;
    }
    return self._get_mongo_collection(col_name).find_one(filter);
}

impl Db.find(col_name: str, filter: dict) -> Cursor | list {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "find() with filters is not supported for Redis. "
            "Redis is a key-value store. Use scan_keys(pattern) for pattern matching."
        ) ;
    }
    return self._get_mongo_collection(col_name).find(filter);
}

impl Db.insert_one(
    col_name: str, document: dict
) -> PyMongoInsertOneResult | InsertResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "insert_one() is not supported for Redis. Use set(key, value) instead."
        ) ;
    }
    return self._get_mongo_collection(col_name).insert_one(document);
}

impl Db.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "update_one() with filters is not supported for Redis. "
            "Use set(key, value) to update a value."
        ) ;
    }
    return self._get_mongo_collection(col_name).update_one(
        filter, update_data, upsert=upsert_mode
    );
}

impl Db.delete_one(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "delete_one() with filters is not supported for Redis. "
            "Use delete(key) instead."
        ) ;
    }
    return self._get_mongo_collection(col_name).delete_one(filter);
}

# Bulk operations (MongoDB only)
impl Db.insert_many(
    col_name: str, documents: list
) -> PyMongoInsertManyResult | InsertManyResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "insert_many() is not supported for Redis. "
            "Use set(key, value) in a loop or use Redis pipelines."
        ) ;
    }
    return self._get_mongo_collection(col_name).insert_many(documents);
}

impl Db.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "update_many() with filters is not supported for Redis. "
            "Redis does not support bulk updates with filters."
        ) ;
    }
    return self._get_mongo_collection(col_name).update_many(
        filter, update_data, upsert=upsert_mode
    );
}

impl Db.delete_many(col_name: str, filter: dict) -> PyMongoDeleteResult | DeleteResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "delete_many() with filters is not supported for Redis. "
            "Use scan_keys(pattern) to find keys, then delete them individually."
        ) ;
    }
    return self._get_mongo_collection(col_name).delete_many(filter);
}

# ID-based convenience methods (MongoDB only, but map to get/set/delete for Redis)
impl Db.find_by_id(
    col_name: str, id: str
) -> dict | None {
    if self.db_type == DatabaseType.MONGODB {
        return self._get_mongo_collection(col_name).find_one({'_id': ObjectId(id)});
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, this is just an alias for get()
        return self.get(id, col_name);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    if self.db_type == DatabaseType.REDIS {
        raise NotImplementedError(
            "update_by_id() is not supported for Redis. "
            "Use get(key) to retrieve, modify, then set(key, value)."
        ) ;
    }
    return self._get_mongo_collection(col_name).update_one(
        {'_id': ObjectId(id)}, update_data, upsert=upsert_mode
    );
}

impl Db.delete_by_id(col_name: str, id: str) -> PyMongoDeleteResult | DeleteResult {
    if self.db_type == DatabaseType.MONGODB {
        return self._get_mongo_collection(col_name).delete_one({'_id': ObjectId(id)});
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, return a compatible result object
        deleted = self.delete(id, col_name);
        return DeleteResult(deleted_count=deleted);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

# ===== REDIS-ONLY METHODS =====
impl Db.set_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    if self.db_type == DatabaseType.MONGODB {
        raise NotImplementedError(
            "set_with_ttl() is not supported for MongoDB. "
            "MongoDB uses TTL indexes, not per-key expiration."
        ) ;
    }
    return self.client.setex(
        self._get_redis_key(col_name, key), ttl, json.dumps(value)
    );
}

impl Db.incr(key: str, col_name: str = 'default') -> int {
    if self.db_type == DatabaseType.MONGODB {
        raise NotImplementedError(
            "incr() is not supported for MongoDB. "
            "Use update_one() with $inc operator instead."
        ) ;
    }
    return self.client.incr(self._get_redis_key(col_name, key));
}

impl Db.expire(key: str, seconds: int, col_name: str = 'default') -> bool {
    if self.db_type == DatabaseType.MONGODB {
        raise NotImplementedError(
            "expire() is not supported for MongoDB. "
            "MongoDB uses TTL indexes for document expiration."
        ) ;
    }
    return self.client.expire(self._get_redis_key(col_name, key), seconds);
}

impl Db.scan_keys(pattern: str, col_name: str = 'default') -> list[str] {
    if self.db_type == DatabaseType.MONGODB {
        raise NotImplementedError(
            "scan_keys() is not supported for MongoDB. "
            "Use find() with filters instead."
        ) ;
    }
    # Build pattern with namespace
    full_pattern = self._get_redis_key(col_name, pattern);
    keys = [];
    # Use SCAN instead of KEYS for better performance
    for key in self.client.scan_iter(match=full_pattern) {
        # Remove the prefix to return just the key portion
        key_str = key.decode('utf-8') if isinstance(key, bytes) else key;
        # Extract just the key part (after last ':')
        keys.append(key_str.split(':')[-1]);
    }
    return keys;
}

# ===== UTILITY =====
def get_db -> Db {
    import from jac_scale.db { get_mongo_client }
    # Default to MongoDB for backward compatibility
    return Db(
        client=get_mongo_client(), db_name='jac_db', db_type=DatabaseType.MONGODB
    );
}
