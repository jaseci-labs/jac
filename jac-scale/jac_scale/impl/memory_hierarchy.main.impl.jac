"""MemoryOrchestrator Implementation - Multi-tier storage coordination."""
import from uuid { UUID }
import from collections.abc { Iterable }
import from jaclang.pycore.archetype { Anchor }
import from jaclang.runtimelib.storage { logger }

"""Initialize MemoryOrchestrator with multi-tier storage."""
impl MemoryOrchestrator.init -> None {
    # L2: Try to initialize Redis cache
    redis_backend = RedisBackend();
    self._cache_available = redis_backend.is_available();
    if self._cache_available {
        self.cache = redis_backend;
        logger.info("Redis cache backend initialized");
    } else {
        self.cache = None;
        logger.info("Redis not available, running without distributed cache");
    }
    # L3: Try MongoDB first, fall back to Shelf
    mongo_backend = MongoBackend();
    persistence: (PersistenceBackend | None) = None;
    if mongo_backend.is_available() {
        persistence = mongo_backend;
        self._persistence_type = 'mongodb';
        logger.info("MongoDB persistence backend initialized");
    } else {
        persistence = ShelfBackend();
        self._persistence_type = 'shelf';
        logger.info("MongoDB not available, using Shelf for persistence");
    }
    # Initialize base class with persistence (creates L1 memory)
    super.init(persistence);
}

"""Retrieve anchor with read-through caching. L1 -> L2 -> L3."""
impl MemoryOrchestrator.get(id: UUID) -> (Anchor | None) {
    # L1: Check in-memory cache
    if (anchor := self.memory.get(id)) {
        return anchor;
    }
    # L2: Check distributed cache (Redis)
    if self._cache_available and self.cache {
        if (anchor := self.cache.get(id)) {
            # Promote to L1
            self.memory.put(anchor);
            return anchor;
        }
    }
    # L3: Check persistence (MongoDB or Shelf)
    if self.persistence {
        if (anchor := self.persistence.get(id)) {
            # Promote to L1
            self.memory.put(anchor);
            # Promote to L2 if available
            if self._cache_available and self.cache {
                self.cache.put(anchor);
            }
            return anchor;
        }
    }
    return None;
}

"""Commit changes to persistence layer."""
impl MemoryOrchestrator.commit(anchor: (Anchor | None) = None) -> None {
    try {
        gc = self.memory.get_gc();

        # Handle garbage collected anchors (deletions)
        for anc in gc {
            self._delete_from_backends(anc.id);
            self.memory.remove_from_gc(anc);
        }

        # Handle single anchor commit
        if anchor {
            if self.persistence {
                self.persistence.put(anchor);
            }
            # Update cache if key exists (conditional write)
            if self._cache_available and self.cache {
                self.cache.put_if_exists(anchor);
            }
            return;
        }

        # Handle bulk commit of all memory contents
        anchors = list(self.memory.get_mem().values());
        self._sync_to_backends(anchors);
    } except Exception as e {
        logger.error(f"Commit failed: {e}");
    }
}

"""Commit pending changes and close all backends."""
impl MemoryOrchestrator.close -> None {
    self.commit();
    self.memory.close();
    if self.cache {
        self.cache.close();
    }
    if self.persistence {
        self.persistence.close();
    }
}

"""Sync anchors to cache and persistence backends."""
impl MemoryOrchestrator._sync_to_backends(anchors: Iterable[Anchor]) -> None {
    anchor_list = list(anchors);
    try {
        # Update cache for existing keys only
        if self._cache_available and self.cache {
            for anchor in anchor_list {
                self.cache.put_if_exists(anchor);
            }
        }

        # Write to persistence
        if self.persistence {
            self.persistence.bulk_put(anchor_list);
        }
    } except Exception as e {
        logger.error(f"Sync to backends failed: {e}");
    }
}

"""Delete anchor from all backend tiers."""
impl MemoryOrchestrator._delete_from_backends(id: UUID) -> None {
    try {
        if self._cache_available and self.cache {
            self.cache.delete(id);
        }
        if self.persistence {
            self.persistence.delete(id);
        }
    } except Exception as e {
        logger.error(f"Delete from backends failed: {e}");
    }
}
