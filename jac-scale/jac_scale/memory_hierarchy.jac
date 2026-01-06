"""
Memory Hierarchy Implementation for jac-scale.

This module provides scalable storage backends:
- MongoBackend: MongoDB-based persistent storage (L3)
- RedisBackend: Redis-based distributed cache (L2)
- ShelfBackend: File-based persistent storage (L3 fallback)
- ScaleTieredMemory: Extends TieredMemory with Redis L2 and MongoDB L3

Extends the core memory hierarchy from jaclang.runtimelib.memory.
"""
import os;
import shelve;
import logging;
import from collections.abc { Callable, Generator, Iterable, MutableMapping }
import from pickle { dumps, loads }
import from threading { RLock }
import from typing { Any, cast }
import from uuid { UUID }
import redis;
import from pymongo { MongoClient, UpdateOne }
import from pymongo.errors { ConnectionFailure }
import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.memory {
    Memory,
    CacheMemory,
    PersistentMemory,
    VolatileMemory,
    TieredMemory
}
import from jaclang.runtimelib.utils { storage_key, to_uuid }
import from jac_scale.config_loader { get_scale_config }

# Load database configuration from jac.toml with env var overrides
glob _db_config = get_scale_config().get_database_config(),
     logger = logging.getLogger(__name__);

"""
MongoDB persistence backend.
Implements PersistentMemory for durable anchor storage.
"""
obj MongoBackend(PersistentMemory) {
    has client: (MongoClient | None) = None,
        db_name: str = 'jac_db',
        collection_name: str = 'anchors',
        mongo_url: str = _db_config['mongodb_uri'],
        __mem__: dict[UUID, Anchor] = {},
        __gc__: set[Anchor] = {};

    def postinit -> None;
    # Memory interface
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    # PersistentMemory interface
    def sync -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Additional methods
    def get_gc -> list[Anchor];
    def remove_from_gc(anchor: Anchor) -> None;
    def get_mem -> dict[UUID, Anchor];
    # Internal
    def _load_anchor(raw: dict[(str, Any)]) -> (Anchor | None);
}

"""
Redis cache backend.
Implements CacheMemory for distributed caching.
"""
obj RedisBackend(CacheMemory) {
    has redis_url: str = _db_config['redis_url'],
        redis_client: (redis.Redis | None) = None,
        __mem__: dict[UUID, Anchor] = {},
        __gc__: set[Anchor] = {};

    def postinit -> None;
    # Memory interface
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    # CacheMemory interface
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
    # Additional methods
    def get_gc -> list[Anchor];
    def remove_from_gc(anchor: Anchor) -> None;
    def get_mem -> dict[UUID, Anchor];
}

"""
Shelf persistence backend.
Implements PersistentMemory for file-based storage.
Uses dbm.dumb on all platforms to avoid gdbm locking issues.
"""
obj ShelfBackend(PersistentMemory) {
    has shelf_path: str = _db_config['shelf_db_path'],
        _shelf: (shelve.Shelf | None) = None,
        _lock: (RLock | None) = None,
        __mem__: dict[UUID, Anchor] = {},
        __gc__: set[Anchor] = {};

    def postinit -> None;
    # Memory interface
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    # PersistentMemory interface
    def sync -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Additional methods
    def get_gc -> list[Anchor];
    def remove_from_gc(anchor: Anchor) -> None;
    def get_mem -> dict[UUID, Anchor];
    def sync_from_memory(memory: dict[UUID, Anchor], gc_set: set[Anchor]) -> None;
    # Internal
    def _open_shelf -> shelve.Shelf;
    def _ensure_shelf -> shelve.Shelf;
}

"""
Scalable Tiered Memory - Extends TieredMemory with distributed backends.

Provides:
- L1: In-memory cache (VolatileMemory from base class)
- L2: Distributed cache (Redis via RedisBackend)
- L3: Persistent storage (MongoDB or Shelf)

Used by JScaleExecutionContext for scaled deployments.
"""
obj ScaleTieredMemory(TieredMemory) {
    has _cache_available: bool = False,
        _persistence_type: str = 'none',
        session_path: (str | None) = None;

    def init(session: (str | None) = None, use_cache: bool = True) -> None;
    # Override to add L2 cache layer awareness
    def close -> None;
}
