"""MongoDB PersistenceBackend Implementation."""
import logging;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from typing { Any, cast }
import from uuid { UUID }
import from pymongo { MongoClient, UpdateOne }
import from pymongo.errors { ConnectionFailure }
import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);

"""Post-initialization: connect to MongoDB."""
impl MongoBackend.postinit -> None {
    if self.client is None and self.mongo_url {
        try {
            self.client = MongoClient(self.mongo_url);
            self.db = self.client[self.db_name];
            self.collection = self.db[self.collection_name];
        } except Exception as e {
            logger.debug(f"MongoDB connection failed: {e}");
            self.client = None;
        }
    }
}

"""Check if MongoDB is available and connected."""
impl MongoBackend.is_available -> bool {
    if not self.mongo_url {
        return False;
    }
    client = None;
    try {
        client = MongoClient(self.mongo_url);
        client.admin.command('ping', maxTimeMS=100);
        return True;
    } except ConnectionFailure {
        return False;
    } except Exception as e {
        logger.debug(f"MongoDB availability check failed: {e}");
        return False;
    } finally {
        if client {
            try {
                client.close();
            } except Exception { }
        }
    }
}

"""Get anchor by UUID from MongoDB."""
impl MongoBackend.get(id: UUID) -> (Anchor | None) {
    if self.client is None {
        return None;
    }
    _id = to_uuid(id);
    try {
        db_obj = self.collection.find_one({'_id': str(_id)});
        if db_obj {
            return self._load_anchor(db_obj);
        }
    } except Exception as e {
        logger.debug(f"MongoDB get failed: {e}");
    }
    return None;
}

"""Store anchor in MongoDB."""
impl MongoBackend.put(anchor: Anchor) -> None {
    if self.client is None or not anchor.persistent {
        return;
    }
    _id = to_uuid(anchor.id);
    try {
        data_blob = dumps(anchor);
        self.collection.update_one(
            {'_id': str(_id)},
            {'$set': {'data': data_blob, 'type': type(anchor).__name__}},
            upsert=True
        );
    } except Exception as e {
        logger.debug(f"MongoDB put failed: {e}");
    }
}

"""Delete anchor from MongoDB."""
impl MongoBackend.delete(id: UUID) -> None {
    if self.client is None {
        return;
    }
    _id = to_uuid(id);
    try {
        self.collection.delete_one({'_id': str(_id)});
    } except Exception as e {
        logger.debug(f"MongoDB delete failed: {e}");
    }
}

"""Close MongoDB connection."""
impl MongoBackend.close -> None {
    if self.client {
        try {
            self.client.close();
        } except Exception as e {
            logger.warning(f"Error closing MongoDB connection: {e}");
        }
        self.client = None;
    }
}

"""Check if an anchor exists in MongoDB."""
impl MongoBackend.has(id: UUID) -> bool {
    if self.client is None {
        return False;
    }
    _id = to_uuid(id);
    try {
        return self.collection.count_documents({'_id': str(_id)}, limit=1) > 0;
    } except Exception {
        return False;
    }
}

"""Query all anchors with optional filter."""
impl MongoBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    if self.client is None {
        return;
    }
    try {
        for doc in self.collection.find() {
            if (anchor := self._load_anchor(doc)) {
                if filter is None or filter(anchor) {
                    yield anchor;
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB query failed: {e}");
    }
}

"""Get all root anchors."""
impl MongoBackend.get_roots -> Generator[Root, None, None] {
    for anchor in self.query() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl MongoBackend.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl MongoBackend.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Commit - no-op for MongoDB (writes are immediate)."""
impl MongoBackend.commit(anchor: (Anchor | None) = None) -> None {
# No-op: MongoDB writes are immediate
}

# PersistentMemory-specific methods
"""Sync - no-op for MongoDB (writes are immediate)."""
impl MongoBackend.sync -> None {
# No-op: MongoDB writes are immediate
}

"""Bulk store multiple anchors."""
impl MongoBackend.bulk_put(anchors: Iterable[Anchor]) -> None {
    if self.client is None {
        return;
    }
    ops: list = [];
    for anchor in anchors {
        if not anchor.persistent {
            continue;
        }
        _id = to_uuid(anchor.id);
        try {
            data_blob = dumps(anchor);
            ops.append(
                UpdateOne(
                    {'_id': str(_id)},
                    {'$set': {'data': data_blob, 'type': type(anchor).__name__}},
                    upsert=True
                )
            );
        } except Exception as e {
            logger.debug(f"MongoDB bulk_put serialization failed: {e}");
        }
    }
    if ops {
        try {
            self.collection.bulk_write(ops);
        } except Exception as e {
            logger.debug(f"MongoDB bulk_write failed: {e}");
        }
    }
}

"""Load anchor from raw MongoDB document."""
impl MongoBackend._load_anchor(raw: dict[(str, Any)]) -> (Anchor | None) {
    if 'data' not in raw {
        return None;
    }
    try {
        data: bytes = raw['data'];
        return loads(data);
    } except Exception as e {
        logger.debug(f"MongoDB _load_anchor failed: {e}");
        return None;
    }
}
