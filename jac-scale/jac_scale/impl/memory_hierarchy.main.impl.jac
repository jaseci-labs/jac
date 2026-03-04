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

"""Commit changes: flush L1 anchors to persistent storage (MongoDB/SQLite)."""
impl ScaleTieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 is None {
        return;
    }
    # Single anchor commit
    if anchor is not None {
        # Early return if anchor is not valid for persistence
        if not isinstance(anchor, Anchor) or not anchor.persistent {
            return;
        }
        typed_anchor = cast(Anchor, anchor);
        # Early return if no write access
        if not Jac.check_write_access(typed_anchor) {
            return;
        }
        try {
            self.l3.put(typed_anchor);
            # Also update L2 cache if available
            if self.l2 {
                self.l2.put(typed_anchor);
            }
        } except Exception as e {
            logger.warning(f"ScaleTieredMemory.commit(anchor) failed: {e}");
        }
        return;
    }
    # Flush all L1 anchors to L3 (and L2 if available)
    for (_, mem_anchor) in list(self.__mem__.items()) {
        if not mem_anchor.persistent or not Jac.check_write_access(mem_anchor) {
            continue;
        }
        try {
            self.l3.put(mem_anchor);
            if self.l2 {
                self.l2.put(mem_anchor);
            }
        } except Exception as e {
            logger.warning(
                f"ScaleTieredMemory.commit flush failed for anchor "
                f"{mem_anchor.id}: {e}"
            );
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
