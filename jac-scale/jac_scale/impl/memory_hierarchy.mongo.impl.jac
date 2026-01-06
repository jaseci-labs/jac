"""MongoDB PersistenceBackend Implementation."""
import from pymongo { MongoClient, UpdateOne }
import from pymongo.errors { ConnectionFailure }
import from uuid { UUID }
import from typing { Any }
import from collections.abc { Iterable }
import from jaclang.pycore.archetype { Anchor }
import logging;
import from jaclang.runtimelib.storage { AnchorMergeStrategy }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);


impl MongoBackend.postinit -> None {
    if self.client is None and self.mongo_url {
        self.client = MongoClient(self.mongo_url);
        self.db = self.client[self.db_name];
        self.collection = self.db[self.collection_name];
    }
}


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


impl MongoBackend.get(id: UUID) -> (Anchor | None) {
    _id = to_uuid(id);
    db_obj = self.collection.find_one({'_id': str(_id)});
    if db_obj {
        return self._load_anchor(db_obj);
    }
    return None;
}


impl MongoBackend.put(anchor: Anchor) -> None {
    if not AnchorMergeStrategy.needs_persist(anchor) {
        return;
    }

    _id = to_uuid(anchor.id);

    # Load existing anchor for merge
    db_doc = self.collection.find_one({'_id': str(_id)});
    stored_anchor = self._load_anchor(db_doc) if db_doc else None;

    # Merge with access control
    final_anchor = AnchorMergeStrategy.merge(anchor, stored_anchor);

    # Serialize
    data_blob = AnchorMergeStrategy.serialize(final_anchor);
    if data_blob is None {
        return;
    }

    # Upsert to MongoDB
    self.collection.update_one(
        {'_id': str(_id)},
        {'$set': {'data': data_blob, 'type': <>type(final_anchor).__name__}},
        upsert=True
    );
}


impl MongoBackend.delete(id: UUID) -> None {
    _id = to_uuid(id);
    self.collection.delete_one({'_id': str(_id)});
}


impl MongoBackend.bulk_put(anchors: Iterable[Anchor]) -> None {
    ops: list = [];

    for anchor in anchors {
        if not AnchorMergeStrategy.needs_persist(anchor) {
            continue;
        }

        _id = to_uuid(anchor.id);

        # Load existing anchor for merge
        db_doc = self.collection.find_one({'_id': str(_id)});
        stored_anchor = self._load_anchor(db_doc) if db_doc else None;

        # Merge with access control
        final_anchor = AnchorMergeStrategy.merge(anchor, stored_anchor);

        # Serialize
        data_blob = AnchorMergeStrategy.serialize(final_anchor);
        if data_blob is None {
            continue;
        }

        ops.append(
            UpdateOne(
                {'_id': str(_id)},
                {'$set': {'data': data_blob, 'type': <>type(final_anchor).__name__}},
                upsert=True
            )
        );
    }

    if ops {
        self.collection.bulk_write(ops);
    }
}


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


impl MongoBackend._load_anchor(raw: dict[(str, Any)]) -> (Anchor | None) {
    if 'data' not in raw {
        return None;
    }
    data: bytes = raw['data'];
    return AnchorMergeStrategy.deserialize(data);
}
