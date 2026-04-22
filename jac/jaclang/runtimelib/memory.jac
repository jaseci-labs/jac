"""Memory Hierarchy for Jac Language.

This module defines the complete memory hierarchy:

Abstract Interfaces:
- Memory: Base interface for all memory operations
- CacheMemory: Extends Memory with ephemeral cache operations (L2)
- PersistentMemory: Extends Memory with durable storage operations (L3)

Concrete Implementations:
- VolatileMemory: Simple dict-based, no persistence (L1)
- LocalCacheMemory: In-process cache with TTL support (L2)
- SqliteMemory: SQLite-based persistent memory with proper concurrency (L3)
- TieredMemory: Composes L1 + L2 + L3 with write-through semantics

jac-scale extends this to override L2 (Redis) and L3 (database).
"""

import logging;
import sqlite3;
import threading;
import from collections.abc { Callable, Generator, Iterable }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }

glob logger = logging.getLogger(__name__),
     __all__ = [
         'Memory',
         'CacheMemory',
         'PersistentMemory',
         'VolatileMemory',
         'LocalCacheMemory',
         'SqliteMemory',
         'TieredMemory'
     ];

# =============================================================================
# Abstract Interfaces
# =============================================================================
"""Base Memory Interface.

All memory implementations (volatile, cache, persistent, tiered) implement this interface.
This enables ExecutionContext to work with any memory type transparently.
"""
obj Memory {
    def is_available -> bool abs;
    def get(id: UUID) -> (Anchor | None) abs;
    def put(anchor: Anchor) -> None abs;
    def delete(id: UUID) -> None abs;
    def close -> None abs;
    def `has(id: UUID) -> bool abs;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None] abs;

    def get_roots -> Generator[Root, None, None] abs;
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None] abs;

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None) abs;

    def commit(anchor: (Anchor | None) = None) -> None abs;
    def get_gc -> list[Anchor] abs;
    def remove_from_gc(anchor: Anchor) -> None abs;
    def get_mem -> dict[UUID, Anchor] abs;
    # ---- Async hot-path mirrors ----
    # Non-abstract: default implementations delegate to the sync variant via
    # asyncio.to_thread so every existing backend (SQLite, Volatile, Tiered)
    # gets non-blocking behavior under an event loop without a rewrite. Native
    # async backends (aiosqlite, asyncpg, motor) can override these to drop
    # the thread hop entirely.
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
    async def adelete(id: UUID) -> None;
    async def ahas(id: UUID) -> bool;
    async def acommit(anchor: (Anchor | None) = None) -> None;
}

"""Cache Memory Interface.

Extends Memory with operations specific to ephemeral caching.
Cache backends are expected to be fast but data loss is acceptable.
Used for L2 (local or distributed cache like Redis) in the tiered hierarchy.
"""
obj CacheMemory(Memory) {
    def exists(id: UUID) -> bool abs;
    def put_if_exists(anchor: Anchor) -> bool abs;
    def invalidate(id: UUID) -> None abs;
}

"""Persistent Memory Interface.

Extends Memory with operations specific to durable storage.
Implementations must guarantee data durability after sync().

The second block of abstract methods (`inspect_summary` onward) is the
backend-agnostic surface that the `jac db` CLI calls into. Any backend
plugin that implements PersistentMemory automatically gets the full
Layer 1+2+3 feature set — schema fingerprints, quarantine-on-failure,
alias-based class rename resolution, operator rescue — exposed via a
uniform CLI, regardless of whether the underlying store is SQLite,
MongoDB, Postgres, or anything else.
"""
obj PersistentMemory(Memory) {
    def sync -> None abs;
    def bulk_put(anchors: Iterable[Anchor]) -> None abs;
    # ---- Layer 1+2+3 operator/inspection surface ----
    """Summary for `jac db inspect`: format version, live row count,
    quarantine count, alias count, and per-archetype breakdowns.

    Expected shape:
        {
            'format_version': str,
            'anchors_total': int,
            'anchors_by_type': list[(str, int)],
            'quarantine_total': int,
            'quarantine_by_type': list[(str, int)],
            'aliases_total': int,
            'location': str,  # path / URI / collection name — for display
        }
    """
    def inspect_summary -> dict abs;

    """List the N most recent quarantined anchors.

    Each entry: {'id', 'arch', 'fingerprint', 'error', 'quarantined_at'}.
    Sorted newest-first. `limit` bounds the result size.
    """
    def list_quarantined(limit: int = 50) -> list abs;

    """Full detail for one quarantined anchor by id (or unique prefix).

    Returns None if no row matches, a multi-hit sentinel {'error': ...}
    if a prefix is ambiguous, else {'id', 'type', 'arch_module',
    'arch_type', 'fingerprint', 'error', 'quarantined_at',
    'from_format_version', 'data': <parsed-json>}.
    """
    def show_quarantined(id_prefix: str) -> (dict | None) abs;

    """Attempt to re-deserialize one quarantined row and move it back.

    On success, re-stamps the row with the live class's identity +
    fingerprint so subsequent reads hit the registry directly.
    Returns (True, 'recovered') on success; (False, reason) on failure.
    """
    def recover_one(id_prefix: str) -> tuple abs;

    """Batch variant: attempts every quarantined row.

    Returns (n_recovered: int, still_stuck: list[(id, reason)]).
    """
    def recover_all -> tuple abs;

    """Return all persistent aliases: list of {'old_name', 'new_name',
    'created_at'}."""
    def list_aliases -> list abs;

    """Persist an alias mapping `old_name` -> `new_name` and merge into the
    in-process Serializer registry. Idempotent (INSERT OR REPLACE-style)."""
    def add_alias(old_name: str, new_name: str) -> None abs;

    """Remove an alias. Returns True if an entry was removed, False otherwise."""
    def remove_alias(old_name: str) -> bool abs;
}

# =============================================================================
# Concrete Implementations
# =============================================================================
"""Volatile Memory - Simple in-memory storage with no persistence.

This is the L1 tier in a tiered memory hierarchy. All data is lost when
the process exits. Used as the fast cache layer in TieredMemory.
"""
obj VolatileMemory(Memory) {
    has __mem__: dict[UUID, Anchor] by postinit,
        __gc__: set[Anchor] by postinit;

    def postinit -> None;
    def is_available -> bool;
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
    def get_gc -> list[Anchor];
    def remove_from_gc(anchor: Anchor) -> None;
    def get_mem -> dict[UUID, Anchor];
}

"""Local Cache Memory - In-process cache implementing CacheMemory interface.

Extends VolatileMemory with cache-specific methods (exists, put_if_exists, invalidate).
This is the default L2 tier. jac-scale overrides with Redis-based distributed cache.
"""
obj LocalCacheMemory(VolatileMemory, CacheMemory) {
    # CacheMemory interface
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
}

"""SQLite-based Persistent Memory.

Uses SQLite with WAL mode for concurrent reads and proper transaction support.
Maintains an in-memory cache for fast reads with write-through to database.
"""
obj SqliteMemory(PersistentMemory) {
    has path: str,
        __mem__: dict[UUID, Anchor] by postinit,
        __gc__: set[Anchor] by postinit,
        __conn__: (sqlite3.Connection | None) by postinit,
        __lock__: threading.RLock by postinit,
        l3_fetch_count: int by postinit;

    def postinit -> None;
    # Lazy connection initialization - DB only created when data is written
    def _ensure_connection -> None;
    # Memory interface
    def is_available -> bool;
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
    # PersistentMemory interface
    def sync -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    def inspect_summary -> dict;
    def list_quarantined(limit: int = 50) -> list;
    def show_quarantined(id_prefix: str) -> (dict | None);
    def recover_one(id_prefix: str) -> tuple;
    def recover_all -> tuple;
    def list_aliases -> list;
    def add_alias(old_name: str, new_name: str) -> None;
    def remove_alias(old_name: str) -> bool;
    def get_gc -> list[Anchor];
    def remove_from_gc(anchor: Anchor) -> None;
    def get_mem -> dict[UUID, Anchor];
}

"""Tiered Memory - Extends VolatileMemory with L2 cache + L3 persistent tiers.

This is the main memory abstraction used by ExecutionContext. It provides:
- Fast reads via inherited L1 (VolatileMemory) with L2/L3 fallback and automatic promotion
- Write-through to all tiers with access control
- Configurable tiers (L2 and L3 are optional)
- Automatic L3 initialization when base_path is provided

TieredMemory IS the L1 tier (inherits __mem__, __gc__ from VolatileMemory).
jac-scale extends this by providing Redis-based L2 and database L3.
"""
obj TieredMemory(VolatileMemory) {
    has base_path: (str | None) = None,
        l2: (CacheMemory | None) by postinit,
        l3: (PersistentMemory | None) by postinit,
        use_cache: bool = False;

    def get_l3_fetch_count -> int;
    def reset_l3_fetch_count -> None;
    def postinit -> None;
    # Override only methods that need tiering logic
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def commit(anchor: (Anchor | None) = None) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
}
