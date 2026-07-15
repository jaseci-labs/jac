import json;
import logging;
import time;
import from collections.abc { Callable, Generator, Iterable }
import from datetime { datetime, timezone }
import from pickle { dumps, loads }
import from typing { Any, cast }
import from uuid { UUID }
import from jaclang.scale._optdeps.redis { redis_module as redis }
import from jaclang.scale._optdeps.pymongo { MongoClient, UpdateOne, ConnectionFailure }
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
import from jaclang.scale.config.config_loader {
    get_scale_config,
    normalize_redis_eviction_policy,
    normalize_redis_eviction_samples
}
import from jaclang.scale.memory.l1_invalidation {
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
     _process_cache: dict[str, any] = {};

glob DEFAULT_REDIS_TTL = 3600,
     # Recheck interval so a Redis restart that drops runtime config is re-bounded.
     REDIS_BOUND_RECHECK_SECONDS = 300;

def _get_db_config -> dict {
    return get_scale_config().get_database_config();
}

"""Read a single redis CONFIG GET value, tolerating bytes and missing keys."""
def _redis_config_value(client: any, name: str, fallback: str) -> str {
    value = client.config_get(name).get(name, fallback);
    if isinstance(value, bytes) {
        value = value.decode();
    }
    return str(value or fallback);
}

"""True when the server evicts any key under memory pressure (allkeys-* policy)."""
def _evicts_all_keys(maxmemory: int, policy: str) -> bool {
    return maxmemory > 0 and policy.startswith('allkeys');
}

"""Best-effort apply configured maxmemory + policy; returns the effective values."""
def _apply_redis_eviction(
    client: any, db_config: dict, cur_max: int, cur_policy: str
) -> tuple[int, str] {
    max_memory = db_config.get('redis_max_memory', '200mb');
    policy = normalize_redis_eviction_policy(
        str(db_config.get('redis_eviction_policy', 'allkeys-lru'))
    );
    samples = normalize_redis_eviction_samples(
        str(db_config.get('redis_eviction_samples', 5))
    );
    # Policy before cap so a partial failure never leaves a cap with noeviction.
    try {
        client.config_set('maxmemory-policy', policy);
    } except Exception as e {
        logger.debug(f"Could not set Redis eviction policy (managed instance?): {e}");
        return (cur_max, cur_policy);
    }
    try {
        client.config_set('maxmemory-samples', samples);
    } except Exception as e {
        logger.debug(f"Could not set Redis maxmemory-samples (managed instance?): {e}");
    }
    try {
        client.config_set('maxmemory', max_memory);
    } except Exception as e {
        logger.debug(f"Could not set Redis maxmemory (managed instance?): {e}");
    }
    new_max = int(_redis_config_value(client, 'maxmemory', '0'));
    new_policy = _redis_config_value(client, 'maxmemory-policy', 'noeviction');
    if new_max > 0 and new_policy != 'noeviction' {
        logger.info(
            f"Applied Redis memory bound maxmemory={new_max}, policy={new_policy}."
        );
    }
    return (new_max, new_policy);
}

"""Guarantee the connected Redis bounds its own memory; self-configure or warn, rechecked periodically."""
def _ensure_redis_memory_bound(client: any) -> None {
    now = time.monotonic();
    last = cast(float, _process_cache.get('redis_bound_checked_at', 0.0));
    if last and now - last < REDIS_BOUND_RECHECK_SECONDS {
        return;
    }
    # Throttle set before the work so a transient failure is not retried per request.
    _process_cache['redis_bound_checked_at'] = now;
    try {
        maxmemory = int(_redis_config_value(client, 'maxmemory', '0'));
        policy = _redis_config_value(client, 'maxmemory-policy', 'noeviction');
        db_config = _get_db_config();
        bounded = maxmemory > 0 and policy != 'noeviction';
        if not bounded and db_config.get('redis_enforce_eviction', True) {
            (maxmemory, policy) = _apply_redis_eviction(
                client, db_config, maxmemory, policy
            );
            bounded = maxmemory > 0 and policy != 'noeviction';
        }
        _process_cache['redis_evicts_all_keys'] = _evicts_all_keys(maxmemory, policy);
        if not bounded {
            logger.warning(
                f"Redis has no memory bound (maxmemory={maxmemory}, policy={policy}); "
                f"set maxmemory with an LRU policy or keep a positive redis_default_ttl."
            );
        }
    } except Exception as e {
        # Any Redis blip (CONFIG GET/SET, readback) degrades to unbounded so the
        # availability check never raises and writes fall back to a safe TTL.
        logger.debug(f"Redis memory-bound check failed, treating as unbounded: {e}");
        _process_cache['redis_evicts_all_keys'] = False;
    }
}

"""Resolve the write TTL; a zero TTL is only safe when the server evicts all keys."""
def _resolve_write_ttl(db_config: dict) -> int {
    ttl = int(db_config.get('redis_default_ttl', DEFAULT_REDIS_TTL));
    if ttl > 0 {
        return ttl;
    }
    if _process_cache.get('redis_evicts_all_keys', False) {
        return 0;
    }
    if not _process_cache.get('redis_ttl_fallback_warned') {
        _process_cache['redis_ttl_fallback_warned'] = True;
        logger.warning(
            f"redis_default_ttl=0 ignored: the server does not evict all keys "
            f"(needs an allkeys-* policy); writing keys with fallback "
            f"TTL={DEFAULT_REDIS_TTL}s so memory stays bounded."
        );
    }
    return DEFAULT_REDIS_TTL;
}

obj RedisBackend(CacheMemory) {
    has redis_url: (str | None) = None,
        redis_client: (Any | None) = None,
        _async_redis: (Any | None) = None,
        fetch_count: int = 0,
        put_count: int = 0;

    def postinit -> None;
    def is_available -> bool;
    def reset_counters -> None;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def commit(anchor: (Anchor | None) = None) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
    def publish_invalidation(
        anchor_id: str, origin_l1_id: (str | None) = None
    ) -> None;

    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
}

obj MongoBackend(PersistentMemory) {
    has client: MongoClient | None = None,
        db: any by postinit,
        collection: any by postinit,
        db_name: str = 'jac_db',
        collection_name: str = '_anchors',
        mongo_url: (str | None) = None,
        _l2_ref: (any | None) = None,
        _l1_id: (str | None) = None,
        fetch_count: int = 0,
        put_count: int = 0;

    def postinit -> None;
    def set_cache_ref(cache: (any | None)) -> None;
    def set_l1_id(l1_id: str) -> None;
    def is_available -> bool;
    def reset_counters -> None;
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
    def commit(anchor: (Anchor | None) = None) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def capabilities -> set[str];
    def execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None];
    def ensure_indexes -> None;
    def apply(changeset: ChangeSet) -> ApplyReport;
    def _apply_one(intent: WriteIntent) -> None;
    def inspect_summary -> dict;
    def list_quarantined(limit: int = 50) -> list;
    def show_quarantined(id_prefix: str) -> (dict | None);
    def recover_one(id_prefix: str) -> tuple;
    def recover_all -> tuple;
    def _auto_retry_quarantine(limit: int = 500) -> tuple;
    def list_aliases -> list;
    def add_alias(old_name: str, new_name: str) -> None;
    def remove_alias(old_name: str) -> bool;
    def quarantine_dangling(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None;

    def fsck(repair: bool = False) -> dict;
    def is_recoverable_quarantine(id: UUID) -> bool;
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
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
}

enum PersistenceType { NONE, MONGODB, SQLITE }

obj ScaleTieredMemory(TieredMemory) {
    has _cache_available: bool = False,
        _committed: bool = False,
        _persistence_type: PersistenceType = PersistenceType.NONE,
        _l1_id: str = "",
        use_cache: bool = True;

    def postinit -> None;
    def put(anchor: Anchor) -> None;
    def commit(anchor: (Anchor | None) = None) -> None;
    async def acommit(anchor: (Anchor | None) = None) -> None;
    def close -> None;
    def _mark_committed(anchor: (Anchor | None)) -> None;
    def get(id: UUID) -> (Anchor | None);
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def _refresh_if_stale(id: UUID) -> None;
}
