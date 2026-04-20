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


"""Commit changes: delegate to L3's sync() which handles change detection."""
impl ScaleTieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 is None {
        return;
    }
    # Single anchor commit (explicit save via Jac.commit)
    if anchor is not None {
        if not anchor.persistent {
            return;
        }
        if not Jac.check_write_access(anchor) {
            return;
        }
        try {
            self.l3.put(anchor);
            if self.l2 {
                self.l2.put(anchor);
            }
        } except Exception as e {
            logger.warning(f"ScaleTieredMemory.commit(anchor) failed: {e}");
        }
        return;
    }
    # Batch commit: delegate to L3's sync() which uses hash-based change detection.
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

"""Batch get with tiered read-through: check L1, then batch L3 misses, promote all."""
impl ScaleTieredMemory.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    missing_ids: list[UUID] = [];
    for id in ids {
        if (anchor := self.__mem__.get(id)) {
            result[id] = anchor;
        } else {
            missing_ids.append(id);
        }
    }
    if missing_ids and self.l3 {
        # Use batch_get if L3 supports it (MongoBackend), fall back to get() (SqliteMemory)
        l3_results: dict[UUID, Anchor] = {};
        if hasattr(self.l3, 'batch_get') {
            l3_results = self.l3.batch_get(missing_ids);
        } else {
            for mid in missing_ids {
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

"""Close all backends."""
impl ScaleTieredMemory.close -> None {
    self.commit();
    # Sync and close L3 persistence
    if self.l3 {
        self.l3.sync();
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
