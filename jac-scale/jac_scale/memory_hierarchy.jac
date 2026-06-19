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
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtimelib.changeset {
    ApplyReport,
    ChangeSet,
    WriteIntent,
    WriteOp,
    snapshot_field_hashes
}
import from jaclang.runtimelib.memory {
    CacheMemory,
    PersistentMemory,
    TieredMemory,
    SqliteMemory
}
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.utils { storage_key, to_uuid }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.typecache { get_field_types }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.l1_invalidation {
    DEFAULT_INVALIDATION_CHANNEL,
    build_message,
    consume_stale,
    deregister_l1,
    ensure_listener,
    new_l1_id,
    register_l1
}
import from jaclang { JacRuntimeInterface as Jac }

glob logger = logging.getLogger(__name__),
     # Process-level singletons shared across all requests in a single server process.
     # A single dict so cross-module mutation works without global declarations in each package.
     # Keys: 'mongo_client', 'redis_client', 'mongo_available', 'redis_available', 'system_root'
     _process_cache: dict[str, any] = {};

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
        redis_client: (Any | None) = None,
        _async_redis: (Any | None) = None,
        fetch_count: int = 0,
        put_count: int = 0;

    def postinit -> None;
    def is_available -> bool;
    def reset_counters -> None;
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
    def batch_put(anchors: list[Anchor]) -> None;
    # CacheMemory-specific
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
    # Broadcast a cross-pod L1 eviction; the origin L1 is excluded.
    def publish_invalidation(
        anchor_id: str, origin_l1_id: (str | None) = None
    ) -> None;
    # Async overrides — native redis.asyncio (no asyncio.to_thread)
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
}

"""
MongoDB persistence backend - implements PersistentMemory for durable L3 storage.
Replaces SqliteMemory when MongoDB is available.
"""
obj MongoBackend(PersistentMemory) {
    has client: MongoClient | None = None,
        db: any by postinit,
        collection: any by postinit,
        db_name: str = 'jac_db',
        collection_name: str = '_anchors',
        mongo_url: (str | None) = None,
        _l2_ref: (any | None) = None,
        # L1 id stamped on broadcasts so the writer self-excludes.
        _l1_id: (str | None) = None,
        fetch_count: int = 0,
        put_count: int = 0;

    def postinit -> None;
    def set_cache_ref(cache: (any | None)) -> None;
    def set_l1_id(l1_id: str) -> None;
    def is_available -> bool;
    def reset_counters -> None;
    # PersistentMemory interface (Memory methods + persistence-specific)
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def put_partial(anchor: Anchor, field_names: set[str]) -> None;
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
    # Pushdown protocol — Mongo declares native type+field+id_in+slice support.
    def capabilities -> set[str];
    def execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None];
    # One-time index setup (idempotent). Called from postinit.
    def ensure_indexes -> None;
    def apply(changeset: ChangeSet) -> ApplyReport;
    def _apply_one(intent: WriteIntent) -> None;
    # Layer 1+2+3 operator surface
    def inspect_summary -> dict;
    def list_quarantined(limit: int = 50) -> list;
    def show_quarantined(id_prefix: str) -> (dict | None);
    def recover_one(id_prefix: str) -> tuple;
    def recover_all -> tuple;
    # Startup auto-retry of quarantined docs a new deploy may have fixed
    # (new classes, aliases, or __jac_schema__ drift rules). Returns
    # (attempted, recovered).
    def _auto_retry_quarantine(limit: int = 500) -> tuple;
    def list_aliases -> list;
    def add_alias(old_name: str, new_name: str) -> None;
    def remove_alias(old_name: str) -> bool;
    # Referential-integrity surface (read-path healing + `jac db fsck`)
    def quarantine_dangling(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None;

    def fsck(repair: bool = False) -> dict;
    def is_recoverable_quarantine(id: UUID) -> bool;
    # Internal
    def _load_anchor(raw: dict[(str, Any)]) -> (Anchor | None);
    def _load_db_aliases -> int;
    def _put_node_atomic(
        anchor: NodeAnchor,
        edges_added: list[str],
        edges_removed: list[str],
        fields: set[str],
        cas_version: (int | None) = None
    ) -> None;

    def _write_to_db(anchor: Anchor) -> None;
    # Async overrides — PyMongo AsyncMongoClient (no asyncio.to_thread)
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
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
        _committed: bool = False,
        _persistence_type: PersistenceType = PersistenceType.NONE,
        # Stable id for this context's L1 in the invalidation registry.
        _l1_id: str = "",
        use_cache:
            bool = True;  # Override parent default to enable Redis cache by default

    def postinit -> None;
    def commit(anchor: (Anchor | None) = None) -> None;
    async def acommit(anchor: (Anchor | None) = None) -> None;
    def close -> None;
    def get(id: UUID) -> (Anchor | None);
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def _refresh_if_stale(id: UUID) -> None;
}
