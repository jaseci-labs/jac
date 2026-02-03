"""Database implementation dispatcher.

This file dispatches database operations to the appropriate implementation
based on the db_type (MongoDB or Redis).
"""
import from jac_scale.factories.database_factory { DatabaseType }
import from typing { Any }
import from bson { ObjectId }
import json;

# MongoDB implementations
impl Db.find_one(col_name: str, filter: dict) -> dict | None {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.find_one(filter);
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, use key pattern: {db_name}:{col_name}:{filter_key}
        # Simple implementation: if filter has '_id', use it as key
        if '_id' in filter {
            key = f"{self.db_name}:{col_name}:{filter['_id']}";
            data = self.client.get(key);
            if data {
                return json.loads(data);
            }
        }
        return None;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.find(col_name: str, filter: dict) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.find(filter);
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, return all keys matching pattern
        pattern = f"{self.db_name}:{col_name}:*";
        keys = self.client.keys(pattern);
        results = [];
        for key in keys {
            data = self.client.get(key);
            if data {
                results.append(json.loads(data));
            }
        }
        return results;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.insert_one(col_name: str, document: dict) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.insert_one(document);
    } elif self.db_type == DatabaseType.REDIS {
        # Generate an ID if not provided
        import from uuid { uuid4 }
        if '_id' not in document {
            document['_id'] = str(uuid4());
        }
        key = f"{self.db_name}:{col_name}:{document['_id']}";
        self.client.set(key, json.dumps(document));
        # Return a result object similar to MongoDB
        class InsertResult {
            has inserted_id: str;
        }
        return InsertResult(inserted_id=document['_id']);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.update_one(filter, update_data, upsert=upsert_mode);
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, find the document first, update it, and save
        if '_id' in filter {
            key = f"{self.db_name}:{col_name}:{filter['_id']}";
            data = self.client.get(key);
            if data {
                doc = json.loads(data);
                # Handle $set operator
                if '$set' in update_data {
                    doc.update(update_data['$set']);
                } else {
                    doc.update(update_data);
                }
                self.client.set(key, json.dumps(doc));
                # Return result similar to MongoDB
                class UpdateResult {
                    has matched_count: int,
                        modified_count: int;
                }
                return UpdateResult(matched_count=1, modified_count=1);
            } elif upsert_mode {
                # Create new document
                doc = filter.copy();
                if '$set' in update_data {
                    doc.update(update_data['$set']);
                } else {
                    doc.update(update_data);
                }
                self.client.set(key, json.dumps(doc));
                class UpdateResult {
                    has matched_count: int,
                        modified_count: int,
                        upserted_id: str;
                }
                return UpdateResult(
                    matched_count=0, modified_count=0, upserted_id=filter['_id']
                );
            }
        }
        class UpdateResult {
            has matched_count: int,
                modified_count: int;
        }
        return UpdateResult(matched_count=0, modified_count=0);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.delete_one(col_name: str, filter: dict) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.delete_one(filter);
    } elif self.db_type == DatabaseType.REDIS {
        if '_id' in filter {
            key = f"{self.db_name}:{col_name}:{filter['_id']}";
            deleted = self.client.delete(key);
            # Return result similar to MongoDB
            class DeleteResult {
                has deleted_count: int;
            }
            return DeleteResult(deleted_count=deleted);
        }
        class DeleteResult {
            has deleted_count: int;
        }
        return DeleteResult(deleted_count=0);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.insert_many(col_name: str, documents: list) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.insert_many(documents);
    } elif self.db_type == DatabaseType.REDIS {
        import from uuid { uuid4 }
        inserted_ids = [];
        for doc in documents {
            if '_id' not in doc {
                doc['_id'] = str(uuid4());
            }
            key = f"{self.db_name}:{col_name}:{doc['_id']}";
            self.client.set(key, json.dumps(doc));
            inserted_ids.append(doc['_id']);
        }
        class InsertManyResult {
            has inserted_ids: list;
        }
        return InsertManyResult(inserted_ids=inserted_ids);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.update_many(filter, update_data, upsert=upsert_mode);
    } elif self.db_type == DatabaseType.REDIS {
        # For Redis, find all matching keys and update them
        pattern = f"{self.db_name}:{col_name}:*";
        keys = self.client.keys(pattern);
        matched = 0;
        modified = 0;
        for key in keys {
            data = self.client.get(key);
            if data {
                doc = json.loads(data);
                # Simple filter matching (only exact matches for now)
                matches = True;
                for (k, v) in filter.items() {
                    if doc.get(k) != v {
                        matches = False;
                        break;
                    }
                }
                if matches {
                    matched += 1;
                    if '$set' in update_data {
                        doc.update(update_data['$set']);
                    } else {
                        doc.update(update_data);
                    }
                    self.client.set(key, json.dumps(doc));
                    modified += 1;
                }
            }
        }
        class UpdateResult {
            has matched_count: int,
                modified_count: int;
        }
        return UpdateResult(matched_count=matched, modified_count=modified);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.find_by_id(col_name: str, id: str) -> dict | None {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.find_one({'_id': ObjectId(id)});
    } elif self.db_type == DatabaseType.REDIS {
        key = f"{self.db_name}:{col_name}:{id}";
        data = self.client.get(key);
        if data {
            return json.loads(data);
        }
        return None;
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.update_one({'_id': ObjectId(id)}, update_data, upsert=upsert_mode);
    } elif self.db_type == DatabaseType.REDIS {
        key = f"{self.db_name}:{col_name}:{id}";
        data = self.client.get(key);
        if data {
            doc = json.loads(data);
            if '$set' in update_data {
                doc.update(update_data['$set']);
            } else {
                doc.update(update_data);
            }
            self.client.set(key, json.dumps(doc));
            class UpdateResult {
                has matched_count: int,
                    modified_count: int;
            }
            return UpdateResult(matched_count=1, modified_count=1);
        } elif upsert_mode {
            doc = {'_id': id};
            if '$set' in update_data {
                doc.update(update_data['$set']);
            } else {
                doc.update(update_data);
            }
            self.client.set(key, json.dumps(doc));
            class UpdateResult {
                has matched_count: int,
                    modified_count: int,
                    upserted_id: str;
            }
            return UpdateResult(matched_count=0, modified_count=0, upserted_id=id);
        }
        class UpdateResult {
            has matched_count: int,
                modified_count: int;
        }
        return UpdateResult(matched_count=0, modified_count=0);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

impl Db.delete_by_id(col_name: str, id: str) -> Any {
    if self.db_type == DatabaseType.MONGODB {
        db = self.client[self.db_name];
        col = db[col_name];
        return col.delete_one({'_id': ObjectId(id)});
    } elif self.db_type == DatabaseType.REDIS {
        key = f"{self.db_name}:{col_name}:{id}";
        deleted = self.client.delete(key);
        class DeleteResult {
            has deleted_count: int;
        }
        return DeleteResult(deleted_count=deleted);
    }
    raise ValueError(f"Unsupported database type: {self.db_type}") ;
}

def get_db -> Db {
    import from jac_scale.db { get_mongo_client }
    import from jac_scale.factories.database_factory { DatabaseType }
    # Default to MongoDB for backward compatibility
    return Db(
        client=get_mongo_client(), db_name='jac_db', db_type=DatabaseType.MONGODB
    );
}
