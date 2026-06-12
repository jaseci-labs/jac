"""ScaleTieredMemory Implementation - Multi-tier storage coordination.

Storage configuration comes from environment variables or jac.toml.
"""

"""Initialize ScaleTieredMemory with distributed backends."""
impl ScaleTieredMemory.postinit -> None {
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    self.__gc__ = set();
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
        # Give MongoDB access to L1 memory for sync()
        mongo_backend.set_memory_ref(self.__mem__);
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


"""Commit changes: delegate to L3's sync() which handles change detection
and merge-aware atomic writes."""
impl ScaleTieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 is None {
        return;
    }
    # Both single-anchor and batch commits go through sync() to ensure
    # all writes use merge-aware paths (no direct L3 put bypass).
    # Capture L2-pending anchors BEFORE L3 sync (which updates hashes).
    if self.l3 {
        try {
            l2_pending = [];
            if self.l2 {
                l2_pending = [
                    mem_anchor
                    for (_, mem_anchor) in list(self.__mem__.items())
                    if mem_anchor.persistent
                    and Serializer._compute_hash(mem_anchor) != mem_anchor.hash
                    and Jac.check_write_access(mem_anchor)
                ];
            }
            atomic_ids = self.l3.sync() or set();
            if self.l2 {
                for mem_anchor in l2_pending {
                    if mem_anchor.id in atomic_ids {
                        # _put_node_atomic already broadcast for these.
                        continue;
                    }
                    try {
                        self.l2.put(mem_anchor);
                        # Evict siblings' stale L1 copy after refreshing L2.
                        cast(RedisBackend, self.l2).publish_invalidation(
                            str(mem_anchor.id), self._l1_id
                        );
                    } except Exception as l2_err {
                        logger.warning(f"L2 cache update failed: {l2_err}");
                    }
                }
            }
        } except Exception as e {
            logger.warning(f"ScaleTieredMemory.commit sync failed: {e}");
        }
    }
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

"""Close all backends."""
impl ScaleTieredMemory.close -> None {
    self.commit();
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
    self.__gc__.clear();
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
