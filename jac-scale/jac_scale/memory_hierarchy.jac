"""
Memory Hierarchy Implementation for jac-scale.

This module provides a multi-tiered storage system:
- L1: In-memory cache (Memory class from core)
- L2: Optional distributed cache (Redis via CacheBackend)
- L3: Persistent storage (MongoDB or Shelf via PersistenceBackend)

The StorageOrchestrator manages data flow between tiers with:
- Read-through caching (L3 -> L2 -> L1 on miss)
- Write-through persistence (L1 -> L3 with optional L2 update)
"""
import os;
import shelve;
import logging;
import from collections.abc { Iterable, MutableMapping }
import from pickle { dumps, loads }
import from threading { RLock }
import from typing { Any }
import from uuid { UUID }
import redis;
import from pymongo { MongoClient, UpdateOne }
import from pymongo.errors { ConnectionFailure }
import from jaclang.pycore.archetype { Anchor, NodeAnchor }
import from jaclang.runtimelib.memory { Memory }
import from jaclang.runtimelib.storage {
    DataBackend,
    CacheBackend,
    PersistenceBackend,
    AnchorMergeStrategy,
    StorageOrchestrator as BaseStorageOrchestrator
}
import from jaclang.runtimelib.utils { storage_key, to_uuid }
import from jac_scale.config_loader { get_scale_config }

# Load database configuration from jac.toml with env var overrides
glob _db_config = get_scale_config().get_database_config(),
     logger = logging.getLogger(__name__);

"""
MongoDB persistence backend.
Implements PersistenceBackend for durable anchor storage.
"""
obj MongoBackend(PersistenceBackend) {
    has client: (MongoClient | None) = None,
        db_name: str = 'jac_db',
        collection_name: str = 'anchors',
        mongo_url: str = _db_config['mongodb_uri'];

    def postinit -> None;
    # DataBackend protocol
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    # PersistenceBackend protocol
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Internal
    def _load_anchor(raw: dict[(str, Any)]) -> (Anchor | None);
}

"""
Redis cache backend.
Implements CacheBackend for distributed caching.
"""
obj RedisBackend(CacheBackend) {
    has redis_url: str = _db_config['redis_url'],
        redis_client: (redis.Redis | None) = None;

    def postinit -> None;
    # DataBackend protocol
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    # CacheBackend protocol
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
}

"""
Shelf persistence backend.
Implements PersistenceBackend for file-based storage.
Uses dbm.dumb on all platforms to avoid gdbm locking issues.
"""
obj ShelfBackend(PersistenceBackend) {
    has shelf_path: str = _db_config['shelf_db_path'],
        _shelf: (shelve.Shelf | None) = None,
        _lock: (RLock | None) = None;

    def postinit -> None;
    # DataBackend protocol
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    # PersistenceBackend protocol
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Internal
    def _open_shelf -> shelve.Shelf;
    def _ensure_shelf -> shelve.Shelf;
}

"""
Storage Orchestrator - manages multi-tier storage hierarchy.

Extends the base StorageOrchestrator from jac-core with:
- L2: Distributed cache (optional, Redis)

Coordinates data access across:
- L1: In-memory cache (from base class)
- L2: Distributed cache (optional, Redis)
- L3: Persistent storage (MongoDB or Shelf)
"""
obj StorageOrchestrator(BaseStorageOrchestrator) {
    has cache: (CacheBackend | None) = None,
        _cache_available: bool = False,
        _persistence_type: str = 'none';

    def init -> None;
    # Override base class methods to add L2 cache layer
    def get(id: UUID) -> (Anchor | None);
    def commit(anchor: (Anchor | None) = None) -> None;
    def close -> None;
    # Override internal coordination to include cache
    def _sync_to_backends(anchors: Iterable[Anchor]) -> None;
    def _delete_from_backends(id: UUID) -> None;
}
