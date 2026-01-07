"""
Memory Hierarchy Implementation for jac-scale.

This module provides scalable storage backends that replace the default
implementations in jaclang.runtimelib.memory:
- RedisBackend: Replaces LocalCacheMemory as L2 distributed cache
- MongoBackend: Replaces ShelfMemory as L3 persistent storage

ScaleTieredMemory extends TieredMemory by swapping in these backends.
Falls back to jaclang's ShelfMemory when MongoDB is unavailable.
"""
import logging;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from typing { Any }
import from uuid { UUID }
import redis;
import from pymongo { MongoClient }
import from pymongo.errors { ConnectionFailure }
import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.memory {
    CacheMemory,
    PersistentMemory,
    TieredMemory,
    ShelfMemory
}
import from jaclang.runtimelib.utils { storage_key, to_uuid }
import from jac_scale.config_loader { get_scale_config }

# Load database configuration from jac.toml with env var overrides
glob _db_config = get_scale_config().get_database_config(),
     logger = logging.getLogger(__name__);

"""
Redis cache backend - implements CacheMemory for distributed L2 caching.
Replaces LocalCacheMemory when Redis is available.
"""
obj RedisBackend(CacheMemory) {
    has redis_url: str = _db_config['redis_url'],
        redis_client: (redis.Redis | None) = None;

    def postinit -> None;
    def is_available -> bool;
    # CacheMemory interface (Memory methods + cache-specific)
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
    # CacheMemory-specific
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
}

"""
MongoDB persistence backend - implements PersistentMemory for durable L3 storage.
Replaces ShelfMemory when MongoDB is available.
"""
obj MongoBackend(PersistentMemory) {
    has client: (MongoClient | None) = None,
        db_name: str = 'jac_db',
        collection_name: str = 'anchors',
        mongo_url: str = _db_config['mongodb_uri'];

    def postinit -> None;
    def is_available -> bool;
    # PersistentMemory interface (Memory methods + persistence-specific)
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
    # PersistentMemory-specific
    def sync -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Internal
    def _load_anchor(raw: dict[(str, Any)]) -> (Anchor | None);
}

"""
Scalable Tiered Memory - extends TieredMemory with distributed backends.

Swaps the default implementations:
- L2: RedisBackend instead of LocalCacheMemory (when Redis available)
- L3: MongoBackend instead of ShelfMemory (when MongoDB available)

Falls back to jaclang's ShelfMemory for L3 when MongoDB is unavailable.
"""
obj ScaleTieredMemory(TieredMemory) {
    has _cache_available: bool = False,
        _persistence_type: str = 'none',
        session_path: (str | None) = None;

    def init(session: (str | None) = None, use_cache: bool = True) -> None;
    def close -> None;
}
