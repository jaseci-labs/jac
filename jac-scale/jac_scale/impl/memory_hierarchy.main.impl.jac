"""ScaleTieredMemory Implementation - Multi-tier storage coordination.

Storage configuration comes from environment variables or jac.toml.
"""

"""Initialize ScaleTieredMemory with distributed backends."""
impl ScaleTieredMemory.postinit -> None {
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    # The request's unit of work (typed write intents).
    self.changes = ChangeSet();
    # Register this context's L1 so sibling broadcasts can evict our copies.
    self._l1_id = new_l1_id();
    register_l1(self._l1_id, self);
    # L2: Try to initialize Redis cache (replaces LocalCacheMemory)
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and self.use_cache {
        self.l2 = redis_backend;
        logger.debug("Redis cache backend initialized");
        # Start the process-wide invalidation listener once.
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
    # L3: Try MongoDB first (replaces SqliteMemory), fall back to SqliteMemory
    mongo_backend = MongoBackend();
    if mongo_backend.is_available() {
        self.l3 = mongo_backend;
        # Give MongoDB access to L2 cache so quarantine ops can invalidate Redis
        mongo_backend.set_cache_ref(self.l2);
        # Stamp our L1 id so the backend's broadcasts exclude us.
        mongo_backend.set_l1_id(self._l1_id);
        self._persistence_type = PersistenceType.MONGODB;
        logger.debug("MongoDB persistence backend initialized");
        # Show subtle message (optional - uncomment to enable)
        try {
            import from jaclang.cli.console { console }
            logger.debug("  ✔ Using MongoDB for persistence", style="muted");
        } except Exception { }
    } else {
        # Fall back to jaclang's SqliteMemory using configured path
        self.l3 = SqliteMemory(
            path=get_scale_config().get_database_config()['shelf_db_path']
        );
        self._persistence_type = PersistenceType.SQLITE;
        logger.debug("MongoDB not available, using SqliteMemory for persistence");
        # Show subtle message
        try {
            import from jaclang.cli.console { console }
            logger.debug("  ✔ Using SQLite for persistence", style="muted");
        } except Exception { }
    }
}


"""Commit the unit of work: collect L1 dirtiness into intents (inherited),
flush via the backend's apply(), refresh L2/cross-pod state from what was
actually applied, then re-baseline change tracking. No second hash sweep:
the changeset itself says what was written and how.

A flush failure propagates — like core TieredMemory.commit — so the
request lifecycle can error/abort instead of silently losing the
request's mutations; the changeset is kept for the close-time backstop.
Only the L2 refresh is best-effort (the durable write already landed)."""
impl ScaleTieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 is None {
        self.changes.clear();
        return;
    }
    self._collect_into(self.changes);
    if self.changes.is_empty() {
        return;
    }
    # EDGE_LIST_DELTA intents on Mongo take _put_node_atomic, which
    # invalidates + broadcasts internally; don't double-publish.
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
                    # Evict siblings' stale L1 copy after refreshing L2.
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
}

"""Batch get with full tiered read-through: L1 → L2 MGET → L3 $in."""
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
    # L2: Redis MGET for L1 misses
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
    # L3: MongoDB $in (or SqliteMemory fallback) for L2 misses
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

"""Async commit: offload to thread so delta-merge and L2 update are correct.

MongoBackend.acommit uses a plain bulk_write (last-writer-wins), which
bypasses the delta-merge _put_node_atomic path in sync(). Using
asyncio.to_thread(self.commit) keeps the event loop free while still
running the correct merge-aware sync() + L2 update.
"""
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

"""Close all backends. The commit here is the backstop for non-spawn
endpoints that mutate without an explicit commit — and the retry for a
spawn whose acommit flush failed (a failed flush leaves _committed False);
a failed walker's abort leaves nothing to collect either way. A backstop
failure still propagates (silent data loss is worse), but the tiers are
closed and L1 dropped regardless."""
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
        # Drop this context's L1 from the invalidation registry.
        if self._l1_id {
            deregister_l1(self._l1_id);
        }
        self.__mem__.clear();
        self.changes.clear();
    }
}

"""If a sibling write flagged `id` stale, drop our copy (only if clean) so the
next read reloads it; a dirty entry is kept so the in-flight write survives."""
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

"""Delegate to get() so find honors lower tiers and stale marks (the inherited
VolatileMemory.find is L1-only and would miss both)."""
impl ScaleTieredMemory.find(
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

impl ScaleTieredMemory.find_one(
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

"""L1 scan, snapshotting `__mem__` so iteration is decoupled from concurrent gets."""
impl ScaleTieredMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in list(self.__mem__.values()) {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}
