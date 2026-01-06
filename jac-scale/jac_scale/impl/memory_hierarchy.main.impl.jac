"""ScaleTieredMemory Implementation - Multi-tier storage coordination."""
import logging;
import from jaclang.runtimelib.memory { ShelfMemory }

glob logger = logging.getLogger(__name__);

"""Initialize ScaleTieredMemory with distributed backends."""
impl ScaleTieredMemory.init(
    session: (str | None) = None, use_cache: bool = True
) -> None {
    # Store session path for reference
    self.session_path = session;
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    self.__gc__ = set();
    # L2: Try to initialize Redis cache (replaces LocalCacheMemory)
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and use_cache {
        self.l2 = redis_backend;
        logger.info("Redis cache backend initialized");
    } else {
        self.l2 = None;
        logger.debug("Redis not available, running without distributed cache");
    }
    # L3: Try MongoDB first (replaces ShelfMemory), fall back to ShelfMemory
    mongo_backend = MongoBackend();
    if mongo_backend.is_available() {
        self.l3 = mongo_backend;
        self._persistence_type = 'mongodb';
        logger.info("MongoDB persistence backend initialized");
    } else {
        # Fall back to jaclang's ShelfMemory
        if session {
            self.l3 = ShelfMemory(path=session);
        } else {
            self.l3 = ShelfMemory(path=_db_config['shelf_db_path']);
        }
        self._persistence_type = 'shelf';
        logger.info("MongoDB not available, using ShelfMemory for persistence");
    }
}

"""Close all backends."""
impl ScaleTieredMemory.close -> None {
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
