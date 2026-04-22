"""
Memory Hierarchy Implementation for jac-scale.

This module provides scalable storage backends that replace the default
implementations in jaclang.runtimelib.memory:
- RedisBackend: Replaces LocalCacheMemory as L2 distributed cache
- MongoBackend: Replaces SqliteMemory as L3 persistent storage

ScaleTieredMemory extends TieredMemory by swapping in these backends.
Falls back to jaclang's SqliteMemory when MongoDB is unavailable.
"""
import json;
import logging;
import from collections.abc { Callable, Generator, Iterable }
import from datetime { datetime, timezone }
import from pickle { dumps, loads }
import from typing { Any, cast }
import from uuid { UUID }
import from jac_scale._optdeps.redis { redis_module as redis }
import from jac_scale._optdeps.pymongo { MongoClient, UpdateOne, ConnectionFailure }
import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.memory {
    CacheMemory,
    PersistentMemory,
    TieredMemory,
    SqliteMemory
}
import from jaclang.runtimelib.utils { storage_key, to_uuid }
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.config_loader { get_scale_config }
import from jaclang { JacRuntimeInterface as Jac }

glob logger = logging.getLogger(__name__);

"""Get fresh database config to support dynamic env var changes (e.g., testcontainers)."""
def _get_db_config -> dict {
    return get_scale_config().get_database_config();
}

"""
Redis cache backend - implements CacheMemory for distributed L2 caching.
Replaces LocalCacheMemory when Redis is available.
"""
obj RedisBackend(CacheMemory) {
    has redis_url: (str | None) = None,
        redis_client: (redis.Redis | None) = None;

    def postinit -> None;
    def is_available -> bool;
    # CacheMemory interface (Memory methods + cache-specific)
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    # CacheMemory-specific
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
}

"""
MongoDB persistence backend - implements PersistentMemory for durable L3 storage.
Replaces SqliteMemory when MongoDB is available.
"""
obj MongoBackend(PersistentMemory) {
    has client: MongoClient | None = None,
        db: Any by postinit,
        collection: Any by postinit,
        db_name: str = 'jac_db',
        collection_name: str = '_anchors',
        mongo_url: (str | None) = None,
        _mem_ref: (dict[UUID, Anchor] | None) = None;

    def postinit -> None;
    def set_memory_ref(mem: dict[UUID, Anchor]) -> None;
    def is_available -> bool;
    # PersistentMemory interface (Memory methods + persistence-specific)
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    # PersistentMemory-specific
    def sync -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    # Layer 1+2+3 operator surface
    def inspect_summary -> dict;
    def list_quarantined(limit: int = 50) -> list;
    def show_quarantined(id_prefix: str) -> (dict | None);
    def recover_one(id_prefix: str) -> tuple;
    def recover_all -> tuple;
    def list_aliases -> list;
    def add_alias(old_name: str, new_name: str) -> None;
    def remove_alias(old_name: str) -> bool;
    # Internal
    def _load_anchor(raw: dict[(str, Any)]) -> (Anchor | None);
    def _load_db_aliases -> int;
    def _put_node_atomic(
        anchor: NodeAnchor, edges_added: list[str], edges_removed: list[str]
    ) -> None;

    def _write_to_db(anchor: Anchor) -> None;
}

"""
Persistence backend type for ScaleTieredMemory.
"""
enum PersistenceType {
    NONE,
    MONGODB,
    SQLITE
}

"""
Scalable Tiered Memory - extends TieredMemory with distributed backends.

Swaps the default implementations:
- L2: RedisBackend instead of LocalCacheMemory (when Redis available)
- L3: MongoBackend instead of SqliteMemory (when MongoDB available)

Falls back to jaclang's SqliteMemory for L3 when MongoDB is unavailable.
Storage configuration comes from environment variables or jac.toml.
"""
obj ScaleTieredMemory(TieredMemory) {
    has _cache_available: bool = False,
        _persistence_type: PersistenceType = PersistenceType.NONE,
        use_cache:
            bool = True;  # Override parent default to enable Redis cache by default

    def postinit -> None;
    def commit(anchor: (Anchor | None) = None) -> None;
    def close -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
}
