import from jac_scale.persistence._db_helpers { _validate_not_read_only }

def _as_object_id(key: str) -> ObjectId | None {
    try {
        return ObjectId(key);
    } except Exception {
        return None;
    }
}

impl MongoDb._get_mongo_collection(col_name: str) -> Collection {
    return self.client[self.db_name][col_name];
}

impl MongoDb.get(key: str, col_name: str = 'default') -> dict | None {
    col = self._get_mongo_collection(col_name);
    result = col.find_one({'_id': key});
    if result is None {
        if (oid := _as_object_id(key)) {
            result = col.find_one({'_id': oid});
        }
    }
    return result;
}

impl MongoDb.set(key: str, value: dict, col_name: str = 'default') -> str {
    _validate_not_read_only(col_name);
    col = self._get_mongo_collection(col_name);
    value_copy = value.copy();
    value_copy['_id'] = key;
    col.replace_one({'_id': key}, value_copy, upsert=True);
    return key;
}

impl MongoDb.delete(key: str, col_name: str = 'default') -> int {
    _validate_not_read_only(col_name);
    col = self._get_mongo_collection(col_name);
    result = col.delete_one({'_id': key});
    if result.deleted_count == 0 {
        if (oid := _as_object_id(key)) {
            result = col.delete_one({'_id': oid});
        }
    }
    return result.deleted_count;
}

impl MongoDb.exists(key: str, col_name: str = 'default') -> bool {
    col = self._get_mongo_collection(col_name);
    exists = col.count_documents({'_id': key}, limit=1) > 0;
    if not exists {
        if (oid := _as_object_id(key)) {
            exists = col.count_documents({'_id': oid}, limit=1) > 0;
        }
    }
    return exists;
}

impl MongoDb.find_one(
    col_name: str, filter: dict, projection: dict | None = None
) -> dict | None {
    col: Any = self._get_mongo_collection(col_name);
    return col.find_one(filter, projection);
}

impl MongoDb.find(
    col_name: str,
    filter: dict,
    projection: dict | None = None,
    limit: int | None = None
) -> Cursor | list {
    col: Any = self._get_mongo_collection(col_name);
    cursor = col.find(filter, projection);
    if limit is not None {
        cursor = cursor.limit(limit);
    }
    return cursor;
}

impl MongoDb.count_documents(col_name: str, filter: dict) -> int {
    col: Any = self._get_mongo_collection(col_name);
    return col.count_documents(filter);
}

impl MongoDb.create_index(
    col_name: str, keys: dict, unique: bool = False, name: str | None = None
) -> str {
    key_spec = [(k, v) for (k, v) in keys.items()];
    col: Any = self._get_mongo_collection(col_name);
    if name is not None {
        return col.create_index(key_spec, unique=unique, name=name);
    }
    return col.create_index(key_spec, unique=unique);
}

impl MongoDb.insert_one(
    col_name: str, document: dict
) -> PyMongoInsertOneResult | InsertResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).insert_one(document);
}

impl MongoDb.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).update_one(
        filter, update_data, upsert=upsert_mode
    );
}

impl MongoDb.delete_one(
    col_name: str, filter: dict
) -> PyMongoDeleteResult | DeleteResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).delete_one(filter);
}

impl MongoDb.insert_many(
    col_name: str, documents: list
) -> PyMongoInsertManyResult | InsertManyResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).insert_many(documents);
}

impl MongoDb.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).update_many(
        filter, update_data, upsert=upsert_mode
    );
}

impl MongoDb.delete_many(
    col_name: str, filter: dict
) -> PyMongoDeleteResult | DeleteResult {
    _validate_not_read_only(col_name);
    return self._get_mongo_collection(col_name).delete_many(filter);
}

impl MongoDb.find_by_id(col_name: str, id: str) -> dict | None {
    if (oid := _as_object_id(id)) {
        return self._get_mongo_collection(col_name).find_one({'_id': oid});
    }
    return None;
}

impl MongoDb.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> PyMongoUpdateResult | UpdateResult {
    _validate_not_read_only(col_name);
    if (oid := _as_object_id(id)) {
        return self._get_mongo_collection(col_name).update_one(
            {'_id': oid}, update_data, upsert=upsert_mode
        );
    }
    return UpdateResult(matched_count=0, modified_count=0);
}

impl MongoDb.delete_by_id(
    col_name: str, id: str
) -> PyMongoDeleteResult | DeleteResult {
    _validate_not_read_only(col_name);
    if (oid := _as_object_id(id)) {
        return self._get_mongo_collection(col_name).delete_one({'_id': oid});
    }
    return DeleteResult(deleted_count=0);
}

impl MongoDb.find_nodes(
    node_type: str, filter: dict = {}, col_name: str = '_anchors'
) -> list {
    mongo_filter: dict = {"data.archetype.__type__": node_type};

    for (key, value) in (filter or {}).items() {
        mongo_filter[f"data.archetype.{key}"] = value;
    }
    col = self._get_mongo_collection(col_name);
    results: list = [];
    for doc in col.find(mongo_filter) {
        if (data := doc.get('data')) {
            if (anchor := Serializer.deserialize(data)) {
                if anchor?.archetype {
                    results.append(anchor.archetype);
                }
            }
        }
    }
    return results;
}
