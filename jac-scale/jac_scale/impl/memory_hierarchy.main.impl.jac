"""ScaleTieredMemory Implementation - Multi-tier storage coordination.

Storage configuration comes from environment variables or jac.toml.
"""

"""Initialize ScaleTieredMemory with distributed backends."""
impl ScaleTieredMemory.init(use_cache: bool = True) -> None {
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    self.__gc__ = set();
    # L2: Try to initialize Redis cache (replaces LocalCacheMemory)
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and use_cache {
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
    # Single anchor commit
    if anchor is not None {
        if not anchor.persistent {
            return;
        }
        if not Jac.check_write_access(anchor) {
            return;
        }
        anchor.is_updated = True;
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
    # Batch commit: delegate to L3's sync()
    # - SQLite: sync() does hash-based change detection (only writes changed anchors)
    # - MongoDB: sync() checks is_updated flag (only writes modified anchors)
    if self.l3 {
        try {
            l2_pending = [];
            if self.l2 {
                l2_pending = [
                    mem_anchor
                    for (_, mem_anchor) in list(self.__mem__.items())
                    if mem_anchor.persistent
                    and mem_anchor.is_updated
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
