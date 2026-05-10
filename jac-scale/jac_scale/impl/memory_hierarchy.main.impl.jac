"""ScaleTieredMemory Implementation - Multi-tier storage coordination.

Storage configuration comes from environment variables or jac.toml.
"""

"""Initialize ScaleTieredMemory with distributed backends."""
impl ScaleTieredMemory.postinit -> None {
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    self.__gc__ = set();
    # L2: Try to initialize Redis cache (replaces LocalCacheMemory)
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and self.use_cache {
        self.l2 = redis_backend;
        logger.debug("Redis cache backend initialized");
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
            self.l3.sync();
            if self.l2 {
                for mem_anchor in l2_pending {
                    try {
                        self.l2.put(mem_anchor);
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

"""Async commit: uses native Motor for L3 and redis.asyncio for L2 when available."""
impl ScaleTieredMemory.acommit(anchor: (Anchor | None) = None) -> None {
    if self.l3 and hasattr(self.l3, 'acommit') {
        try {
            await self.l3.acommit(anchor);
        } except Exception as e {
            logger.warning(f"ScaleTieredMemory.acommit L3 failed: {e}");
        }
    } else {
        await super.acommit(anchor);
    }
}

"""Close all backends."""
impl ScaleTieredMemory.close -> None {
    self.commit();
    if self.l3 {
        self.l3.close();
    }
    # Close L2 cache
    if self.l2 {
        self.l2.close();
    }
    # Clear L1 (inherited from VolatileMemory)
    self.__mem__.clear();
    self.__gc__.clear();
}
