"""Base memory hierachy implementation."""
import os;
import shelve;
import from collections.abc { Iterable, MutableMapping }
import from dataclasses { dataclass, field }
import from pickle { dumps, loads }
import from threading { RLock }
import from typing { Any, TypeVar, cast }
import from uuid { UUID }
import redis;
import from pymongo { MongoClient, UpdateOne }
import from jaclang.runtimelib.archetype { TANCH, Anchor }
import from jaclang.runtimelib.memory { Memory }
with entry {
    ID = TypeVar('ID');
}

@dataclass
class MultiHierarchyMemory(Memory[(UUID, Anchor)]) {
    def __init__(self: MultiHierarchyMemory) -> None {
        super.init();
        self.mem = Memory[(UUID, Anchor)]();
        self.redis = RedisDB();
        self.mongo = MongoDB();
        if not self.redis.redis_is_available() {
            self.shelf = ShelfDB();
        }
    }

    def find_by_id(self: MultiHierarchyMemory, id: UUID) -> (Anchor | None) {
        if (anchor := self.mem.find_by_id(id)) {
            return anchor;
        }
        if self.redis.redis_is_available() {
            if (anchor := self.redis.find_by_id(id)) {
                self.mem.set(anchor);
                return anchor;
            }
            if (anchor := self.mongo.find_by_id(id)) {
                self.mem.set(anchor);
                self.redis.set(anchor);
                return anchor;
            }
        } elif (anchor := self.shelf.find_by_id(id)) {
            self.mem.set(anchor);
            return anchor;
        }
        return None;
    }

    def commit(self: MultiHierarchyMemory, anchor: (Anchor | None) = None) {
        gc = self.mem.get_gc();
        memory = self.mem.get_mem();
        if anchor {
            if (anchor in gc) {
                self.delete(anchor);
                self.mem.remove_from_gc(anchor);
            } elif self.redis.redis_is_available() {
                self.redis.set(anchor);
                self.mongo.set(anchor);
            } else {
                self.shelf.set(anchor);
            }
            return;
        }
        for anchor in gc {
            self.delete(anchor);
            self.mem.remove_from_gc(anchor);
        }
        anchors = <>set(memory.values());
        self.sync(anchors);
    }

    def close(self: MultiHierarchyMemory) {
        self.commit();
        self.mem.close();
    }

    def sync(self: MultiHierarchyMemory, anchors: Iterable[Anchor]) -> None {
        if self.redis.redis_is_available() {
            self.redis.commit(keys=anchors);
            self.mongo.commit(keys=anchors);
        } else {
            self.shelf.commit(keys=anchors);
        }
    }

    def delete(self: MultiHierarchyMemory, anchor: Anchor) {
        self.mem.remove(anchor.id);
        if self.redis.redis_is_available() {
            self.redis.remove(anchor);
            self.mongo.remove(anchor);
        } else {
            self.shelf.commit(anchor);
        }
    }

    def <>set(self: MultiHierarchyMemory, anchor: TANCH) {
        self.mem.set(anchor);
    }
}

"""MongoDB handler."""
@dataclass
class MongoDB {
    with entry {
        client: (MongoClient | None) = field(<>default=None);
        db_name: str = 'jac_db';
        collection_name: str = 'anchors';
        mongo_url = os.environ.get(
            'MONGODB_URI', 'mongodb://root:rootpassword123@localhost:27017/'
        );
    }

    """Initialize Mongodb."""
    def __post_init__(self: MongoDB) -> None {
        if (self.client is None) {
            self.client = MongoClient(self.mongo_url);
        }
        self.db = self.client[self.db_name];
        self.collection = self.db[self.collection_name];
    }

    def _to_uuid(self: MongoDB, id: (UUID | str)) -> UUID {
        if not isinstance(id, UUID) {
            return UUID(str(id));
        }
        return id;
    }

    def _load_anchor(self: MongoDB, raw: dict[(str, Any)]) -> (TANCH | None) {
        try {
            return loads(raw['data']);
        } except Exception {
            return None;
        }
    }

    """\n        Save anchor to MongoDB, exactly like ShelfStorage:\n        - Save all anchors (no empty NodeAnchor skipping)\n        - Update NodeAnchor edges\n        - Respect write and connect access\n        """
    def <>set(self: MongoDB, anchor: Anchor) -> None {
        import from jaclang.runtimelib.archetype { NodeAnchor }
        import from jaclang.runtimelib.runtime { JacRuntimeInterface as Jac }
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
            and (
                getattr(stored_anchor, 'edges', None) != getattr(anchor, 'edges', None)
            )
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
                if (
                    hash(dumps(stored_anchor.archetype)) != hash(
                        dumps(anchor.archetype)
                    )
                ) {
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

    def remove(self: MongoDB, anchor: TANCH) -> None {
        _id = self._to_uuid(anchor.id);
        self.collection.delete_one({'_id': str(_id)});
    }

    def find_by_id(self: MongoDB, id: UUID) -> (Anchor | None) {
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

    """\n        Faster bulk commit:\n        - Deletes anchors in GC\n        - Saves only updated anchors\n        - Uses MongoDB bulk_write for speed\n        """
    def commit_bulk(self: MongoDB, anchors: Iterable[Anchor]) -> None {
        import from jaclang.runtimelib.archetype { NodeAnchor }
        import from jaclang.runtimelib.runtime { JacRuntimeInterface as Jac }
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
                and (
                    getattr(stored_anchor, 'edges', None) != getattr(
                        anc, 'edges', None
                    )
                )
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
                    if (
                        hash(dumps(stored_anchor.archetype)) != hash(
                            dumps(anc.archetype)
                        )
                    ) {
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

    def commit(
        self: MongoDB, anchor: (TANCH | None) = None, keys: Iterable[Anchor] = []
    ) -> None {
        if anchor {
            self.set(anchor);
            return;
        }
        if keys {
            self.commit_bulk(keys);
        }
    }
}

"""Redis-based Memory Handler."""
@dataclass
class RedisDB {
    with entry {
        redis_url: str = os.environ.get(
            'REDIS_URL', 'redis://:mypassword123@localhost:6379/0'
        );
        redis_client: (redis.Redis | None) = field(<>default=None);
    }

    """Initialize Redis."""
    def __post_init__(self: RedisDB) -> None {
        if (self.redis_client is None) {
            self.redis_client = redis.from_url(self.redis_url);
        }
    }

    """Check whether Redis connection is alive and reachable."""
    def redis_is_available(self: RedisDB) -> bool {
        try {
            if (self.redis_client is None) {
                return False;
            }
            return self.redis_client.ping();
        } except Exception {
            return False;
        }
    }

    def _redis_key(self: RedisDB, id: UUID) -> str {
        return f"anchor:{str(id)}";
    }

    def _to_uuid(self: RedisDB, id: (UUID | str)) -> UUID {
        if not isinstance(id, UUID) {
            return UUID(str(id));
        }
        return id;
    }

    def _load_anchor_from_redis(self: RedisDB, id: UUID) -> (Anchor | None) {
        if (self.redis_client is None) {
            return None;
        }
        key = self._redis_key(id);
        raw = self.redis_client.get(key);
        if not raw {
            return None;
        }
        try {
            return loads(raw);
        } except Exception {
            return None;
        }
    }

    """Save to MongoDB AND Redis."""
    def <>set(self: RedisDB, anchor: Anchor) -> None {
        if (self.redis_client is None) {
            return;
        }
        self.redis_client.set(self._redis_key(anchor.id), dumps(anchor));
    }

    """Delete from MongoDB AND Redis."""
    def remove(self: RedisDB, anchor: Anchor) -> None {
        if (self.redis_client is None) {
            return None;
        }
        self.redis_client.delete(self._redis_key(anchor.id));
    }

    def find_by_id(self: RedisDB, id: UUID) -> (Anchor | None) {
        _id = self._to_uuid(id);
        data = self._load_anchor_from_redis(_id);
        return data;
    }

    """Commit behaves like MongoDB but also syncs Redis."""
    def commit(
        self: RedisDB, anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []
    ) -> None {
        if anchor {
            self.set(anchor);
            return;
        }
        if keys {
            for anc in keys {
                self.set(anc);
            }
        }
    }
}

"""Shelf-based Memory Handler — file-backed key/value storage.\n    Uses dbm.dumb on all platforms to avoid gdbm locking issues in Linux.\n    """
@dataclass
class ShelfDB {
    with entry {
        shelf_path: str = field(
            <>default=os.environ.get('SHELF_DB_PATH', 'anchor_store.db')
        );
        _shelf: (shelve.Shelf | None) = field(<>init=False, <>default=None);
        _lock: RLock = field(default_factory=RLock, <>init=False);
    }

    """Initialize shelf DB on startup."""
    def __post_init__(self: ShelfDB) {
        self._open_shelf();
    }

    """Always use dbm.dumb backend to avoid Linux gdbm locking."""
    def _open_shelf(self: ShelfDB) -> shelve.Shelf {
        import dbm.dumb;
        if (self._shelf is None) {
            raw_db = dbm.dumb.open(self.shelf_path, 'c');
            db_as_mapping = cast(MutableMapping[(<>bytes, <>bytes)], raw_db);
            self._shelf = shelve.Shelf(db_as_mapping, writeback=False);
        }
        return self._shelf;
    }

    def _ensure_shelf(self: ShelfDB) -> shelve.Shelf {
        if (self._shelf is None) {
            self._shelf = self._open_shelf();
        }
        return self._shelf;
    }

    """Cleanly close shelf storage."""
    def close(self: ShelfDB) {
        self._shelf = self._ensure_shelf();
        if (self._shelf is not None) {
            self._shelf.close();
            self._shelf = None;
        }
    }

    """Match key format used by Redis for consistency."""
    def _redis_key(self: ShelfDB, id: UUID) -> str {
        return f"anchor:{str(id)}";
    }

    def _to_uuid(self: ShelfDB, id: (UUID | str)) -> UUID {
        if not isinstance(id, UUID) {
            return UUID(str(id));
        }
        return id;
    }

    def _load_anchor_from_shelf(self: ShelfDB, id: UUID) -> (Anchor | None) {
        key = self._redis_key(id);
        shelf = self._ensure_shelf();
        with self._lock {
            if (key not in shelf) {
                return None;
            }
            return shelf[key];
        }
    }

    """Save anchor to shelf."""
    def <>set(self: ShelfDB, anchor: Anchor) -> None {
        key = self._redis_key(anchor.id);
        shelf = self._ensure_shelf();
        with self._lock {
            shelf[key] = anchor;
            shelf.sync();
        }
    }

    """Remove anchor from shelf."""
    def remove(self: ShelfDB, anchor: Anchor) -> None {
        key = self._redis_key(anchor.id);
        shelf = self._ensure_shelf();
        with self._lock {
            if (key in shelf) {
                del (shelf[key], ) ;
                shelf.sync();
            }
        }
    }

    def find_by_id(self: ShelfDB, id: UUID) -> (Anchor | None) {
        _id = self._to_uuid(id);
        return self._load_anchor_from_shelf(_id);
    }

    """Commit one or many anchors."""
    def commit(
        self: ShelfDB, anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []
    ) -> None {
        if anchor {
            self.set(anchor);
            return;
        }
        for anc in keys {
            self.set(anc);
        }
    }
}
