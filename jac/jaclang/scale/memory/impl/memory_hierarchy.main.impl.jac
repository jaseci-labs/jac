def _carries_topology_index(anchor: Anchor) -> bool {
    return isinstance(anchor, NodeAnchor) and anchor.topology_index_data is not None;
}


impl ScaleTieredMemory.postinit -> None {
    self.__mem__ = {};

    self.changes = ChangeSet();

    self._l1_id = new_l1_id();
    register_l1(self._l1_id, self);

    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and self.use_cache {
        self.l2 = redis_backend;
        logger.debug("Redis cache backend initialized");

        try {
            db_config = get_scale_config().get_database_config();
            if db_config.get('redis_l1_invalidation_enabled', True) {
                ensure_listener(
                    _process_cache,
                    cast((str | None), db_config.get('redis_url')),
                    cast(
                        str,
                        db_config.get('redis_l1_invalidation_channel')
                        or DEFAULT_INVALIDATION_CHANNEL
                    )
                );
            }
        } except Exception as e {
            logger.debug(f"L1 invalidation listener init skipped: {e}");
        }
    } else {
        self.l2 = None;
        logger.debug("Redis not available, running without distributed cache");
    }

    hooked_l3 = None;
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        hooked_l3 = Jac.get_persistent_memory(
            {'base_path': self.base_path, 'target_path': self.target_path}
        );
    } except Exception as e {
        logger.debug(f"get_persistent_memory hook failed: {e}");
    }
    if hooked_l3 is not None {
        self.l3 = hooked_l3;
        if isinstance(hooked_l3, MongoBackend) {
            hooked_l3.set_cache_ref(self.l2);
            hooked_l3.set_l1_id(self._l1_id);
            self._persistence_type = PersistenceType.MONGODB;
        } else {
            self._persistence_type = PersistenceType.SQLITE;
        }
        logger.debug("Using get_persistent_memory plugin backend for persistence");
    } elif (mongo_backend := MongoBackend()).is_available() {
        self.l3 = mongo_backend;
        mongo_backend.set_cache_ref(self.l2);
        mongo_backend.set_l1_id(self._l1_id);
        self._persistence_type = PersistenceType.MONGODB;
        logger.debug("MongoDB persistence backend initialized");
        try {
            import from jaclang.cli.console { console }
            logger.debug("  ✔ Using MongoDB for persistence", style="muted");
        } except Exception { }
    } else {
        self.l3 = SqliteMemory(
            path=get_scale_config().get_database_config()['shelf_db_path']
        );
        self._persistence_type = PersistenceType.SQLITE;
        logger.debug("MongoDB not available, using SqliteMemory for persistence");
        try {
            import from jaclang.cli.console { console }
            logger.debug("  ✔ Using SQLite for persistence", style="muted");
        } except Exception { }
    }
}


impl ScaleTieredMemory._mark_committed(anchor: (Anchor | None)) -> None {
    if anchor is None {
        self._committed = True;
    }
}

impl ScaleTieredMemory.put(anchor: Anchor) -> None {
    self._committed = False;
    super.put(anchor);
}

impl ScaleTieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    self._committed = False;
    if self.l3 is None {
        self.changes.clear();
        self._mark_committed(anchor);
        return;
    }
    self._collect_into(self.changes);
    if self.changes.is_empty() {
        self._mark_committed(anchor);
        return;
    }

    self_broadcasting: set = set();
    if isinstance(self.l3, MongoBackend) {
        self_broadcasting = {
            intent.anchor.id
            for intent in self.changes.intents.values()
            if intent.op == WriteOp.EDGE_LIST_DELTA
        };
    }
    apply_report = self.l3.apply(self.changes);
    if self.l2 {
        applied = set(apply_report.applied);
        for intent in list(self.changes.intents.values()) {
            if intent.anchor.id not in applied {
                continue;
            }
            try {
                if intent.is_delete() {
                    self.l2.invalidate(intent.anchor.id);
                    cast(RedisBackend, self.l2).publish_invalidation(
                        str(intent.anchor.id), self._l1_id
                    );
                } elif intent.anchor.id not in self_broadcasting {
                    self.l2.put(intent.anchor);
                    cast(RedisBackend, self.l2).publish_invalidation(
                        str(intent.anchor.id), self._l1_id
                    );
                } elif _carries_topology_index(intent.anchor) {
                    self.l2.invalidate(intent.anchor.id);
                    cast(RedisBackend, self.l2).publish_invalidation(
                        str(intent.anchor.id), self._l1_id
                    );
                }
            } except Exception as l2_err {
                logger.warning(f"L2 cache update failed: {l2_err}");
            }
        }
    }
    self._post_apply(apply_report);
    self.changes.clear();

    if (conflict := apply_report.primary_conflict()) {
        raise conflict;
    }
    self._mark_committed(anchor);
}

impl ScaleTieredMemory.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    l1_misses: list[UUID] = [];
    for id in ids {
        self._refresh_if_stale(id);
        if (anchor := self.__mem__.get(id)) {
            result[id] = anchor;
        } else {
            l1_misses.append(id);
        }
    }
    if not l1_misses {
        return result;
    }

    l2_misses: list[UUID] = [];
    if self.l2 and hasattr(self.l2, 'batch_get') {
        l2_results = self.l2.batch_get(l1_misses);
        for id in l1_misses {
            if id in l2_results {
                anchor = l2_results[id];
                self.__mem__[id] = anchor;
                result[id] = anchor;
            } else {
                l2_misses.append(id);
            }
        }
    } else {
        l2_misses = l1_misses;
    }

    if l2_misses and self.l3 {
        l3_results: dict[UUID, Anchor] = {};
        if hasattr(self.l3, 'batch_get') {
            l3_results = self.l3.batch_get(l2_misses);
        } else {
            for mid in l2_misses {
                if (a := self.l3.get(mid)) {
                    l3_results[mid] = a;
                }
            }
        }
        for (id, anchor) in l3_results.items() {
            self.__mem__[id] = anchor;
            if self.l2 {
                try {
                    self.l2.put(anchor);
                } except Exception { }
            }
            result[id] = anchor;
        }
    }
    return result;
}

impl ScaleTieredMemory.acommit(anchor: (Anchor | None) = None) -> None {
    import asyncio;
    if anchor is None and self._committed {
        return;
    }
    await asyncio.to_thread(self.commit, anchor);
    if anchor is None {
        self._committed = True;
    }
}

impl ScaleTieredMemory.close -> None {
    try {
        if not self._committed {
            self.commit();
        }
    } finally {
        if self.l3 {
            self.l3.close();
        }
        if self.l2 {
            self.l2.close();
        }

        if self._l1_id {
            deregister_l1(self._l1_id);
        }
        self.__mem__.clear();
        self.changes.clear();
    }
}

impl ScaleTieredMemory._refresh_if_stale(id: UUID) -> None {
    if consume_stale(self._l1_id, id) {
        existing = self.__mem__.get(id);
        if existing is not None
        and existing.persistent
        and Serializer._compute_hash(existing) == existing.hash {
            self.__mem__.pop(id, None);
        }
    }
}

impl ScaleTieredMemory.get(id: UUID) -> (Anchor | None) {
    self._refresh_if_stale(id);
    return super.get(id);
}

impl ScaleTieredMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in list(self.__mem__.values()) {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}
