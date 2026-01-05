impl MongoDB.commit(anchor: (TANCH | None) = None, keys: Iterable[Anchor] = []) -> None {
    if anchor {
        self.set(anchor);
        return;
    }
    if keys {
        self.commit_bulk(keys);
    }
}

"""
Faster bulk commit:
- Save all anchors (no empty NodeAnchor skipping)
- Update NodeAnchor edges
- Respect write and connect access
"""
impl MongoDB.commit_bulk(anchors: Iterable[Anchor]) -> None {
    import from jaclang.pycore.archetype { NodeAnchor }
    import from jaclang.pycore.runtime { JacRuntimeInterface as Jac }
    ops: list = [];
    for anc in anchors {
        _id = self._to_uuid(anc.id);
        try {
            current_hash = hash(dumps(anc));
        } except Exception {
            continue;
        }
        if (getattr(anc, 'hash', None) == current_hash) {
            continue;
        }
        db_doc = self.collection.find_one({'_id': str(_id)});
        stored_anchor = self._load_anchor(db_doc) if db_doc else None;
        if (
            stored_anchor
            and isinstance(stored_anchor, NodeAnchor)
            and isinstance(anc, NodeAnchor)
            and (getattr(stored_anchor, 'edges', None) != getattr(anc, 'edges', None))
            and Jac.check_connect_access(anc)
        ) {
            stored_anchor.edges = anc.edges;
            working_anchor = stored_anchor;
        } else {
            working_anchor = anc;
        }
        if (stored_anchor and Jac.check_write_access(anc)) {
            try {
                if (hash(dumps(stored_anchor.access)) != hash(dumps(anc.access))) {
                    stored_anchor.access = anc.access;
                }
                if (hash(dumps(stored_anchor.archetype)) != hash(dumps(anc.archetype))) {
                    stored_anchor.archetype = anc.archetype;
                }
                working_anchor = stored_anchor;
            } except Exception {
                working_anchor = anc;
            }
        }
        try {
            blob = dumps(working_anchor);
        } except Exception {
            continue;
        }
        ops.append(
            UpdateOne(
                {'_id': str(_id)},
                {'$set': {'data': blob, 'type': <>type(working_anchor).__name__}},
                upsert=True
            )
        );
    }
    if ops {
        self.collection.bulk_write(ops);
    }
}

impl MongoDB.find_by_id(id: UUID) -> (Anchor | None) {
    _id = self._to_uuid(id);
    db_obj = self.collection.find_one({'_id': str(_id)});
    if db_obj {
        anchor = self._load_anchor(db_obj);
        if anchor {
            return anchor;
        }
    }
    return None;
}

impl MongoDB.remove(anchor: TANCH) -> None {
    _id = self._to_uuid(anchor.id);
    self.collection.delete_one({'_id': str(_id)});
}

"""
Save anchor to MongoDB, exactly like ShelfStorage:
- Save all anchors (no empty NodeAnchor skipping)
- Update NodeAnchor edges
- Respect write and connect access
"""
impl MongoDB.<>set(anchor: Anchor) -> None {
    import from jaclang.pycore.archetype { NodeAnchor }
    import from jaclang.pycore.runtime { JacRuntimeInterface as Jac }
    _id = self._to_uuid(anchor.id);
    try {
        current_hash = hash(dumps(anchor));
    } except Exception {
        return;
    }
    if (getattr(anchor, 'hash', None) == current_hash) {
        return;
    }
    db_doc = self.collection.find_one({'_id': str(_id)});
    stored_anchor = self._load_anchor(db_doc) if db_doc else None;
    if (
        stored_anchor
        and isinstance(stored_anchor, NodeAnchor)
        and isinstance(anchor, NodeAnchor)
        and (getattr(stored_anchor, 'edges', None) != getattr(anchor, 'edges', None))
        and Jac.check_connect_access(anchor)
    ) {
        stored_anchor.edges = anchor.edges;
        base_anchor = stored_anchor;
    } else {
        base_anchor = anchor;
    }
    if (stored_anchor and Jac.check_write_access(anchor)) {
        try {
            if (hash(dumps(stored_anchor.access)) != hash(dumps(anchor.access))) {
                stored_anchor.access = anchor.access;
            }
            if (hash(dumps(stored_anchor.archetype)) != hash(dumps(anchor.archetype))) {
                stored_anchor.archetype = anchor.archetype;
            }
            final_anchor = stored_anchor;
        } except Exception {
            final_anchor = anchor;
        }
    } else {
        final_anchor = base_anchor;
    }
    try {
        data_blob = dumps(final_anchor);
    } except Exception {
        return;
    }
    self.collection.update_one(
        {'_id': str(_id)},
        {'$set': {'data': data_blob, 'type': <>type(final_anchor).__name__}},
        upsert=True
    );
}

impl MongoDB._load_anchor(raw: dict[(str, Any)]) -> (TANCH | None) {
    try {
        return loads(raw['data']);
    } except Exception {
        return None;
    }
}

impl MongoDB._to_uuid(id: (UUID | str)) -> UUID {
    if not isinstance(id, UUID) {
        return UUID(str(id));
    }
    return id;
}

impl MongoDB.mongo_is_available -> bool {
    client = None;
    if (self.mongo_url) {
        try {
            client = MongoClient(self.mongo_url);

            try {
                client.admin.command('ping', maxTimeMS=100);
                return True;
            } except Exception {
                return False;
            }
        } except ConnectionFailure {
            return False;
        } except Exception {
            return False;
        } finally {
            if (client) {
                try {
                    client.close();
                } except Exception { }
            }
        }
    } else {
        return False;
    }
}

impl MongoDB.close -> None {
    if self.client {
        try {
            self.client.close();
        } except Exception { }
        self.client = None;
    }
}

"""Initialize Mongodb."""
impl MongoDB.postinit -> None {
    if (self.client is None) {
        self.client = MongoClient(self.mongo_url);
    }
    self.db = self.client[self.db_name];
    self.collection = self.db[self.collection_name];
}
