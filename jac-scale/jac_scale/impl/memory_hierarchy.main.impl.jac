"""ScaleTieredMemory Implementation - Multi-tier storage coordination."""
import logging;
import from uuid { UUID }
import from collections.abc { Callable, Iterable }
import from jaclang.pycore.archetype { Anchor }

glob logger = logging.getLogger(__name__);

"""Initialize ScaleTieredMemory with multi-tier storage."""
impl ScaleTieredMemory.init(
    session: (str | None) = None, use_cache: bool = True
) -> None {
    # Store session path for reference
    self.session_path = session;
    # L1: Initialize volatile memory (inherited from VolatileMemory via TieredMemory)
    self.__mem__ = {};
    self.__gc__ = set();
    # L2: Try to initialize Redis cache
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available and use_cache {
        self.l2 = redis_backend;
        logger.info("Redis cache backend initialized");
    } else {
        self.l2 = None;
        logger.info("Redis not available, running without distributed cache");
    }
    # L3: Try MongoDB first, fall back to Shelf
    mongo_backend = MongoBackend();
    if mongo_backend.is_available() {
        self.l3 = mongo_backend;
        self._persistence_type = 'mongodb';
        logger.info("MongoDB persistence backend initialized");
    } else {
        # Use session path if provided, otherwise use default config path
        if session {
            self.l3 = ShelfBackend(shelf_path=session);
        } else {
            self.l3 = ShelfBackend();
        }
        self._persistence_type = 'shelf';
        logger.info("MongoDB not available, using Shelf for persistence");
    }
}

"""Commit pending changes and close all backends."""
impl ScaleTieredMemory.close -> None {
    # Use sync_from_memory for ShelfBackend (handles access control merge strategy)
    if isinstance(self.l3, ShelfBackend) {
        self.l3.sync_from_memory(self.__mem__, set(self.__gc__));
    } elif self.l3 {
        self.commit();
    }
    # Clear L1 (inherited from VolatileMemory)
    self.__mem__.clear();
    self.__gc__.clear();
    # Close L2
    if self.l2 {
        self.l2.close();
    }
    # Close L3
    if self.l3 {
        self.l3.close();
    }
}
