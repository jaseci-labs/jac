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
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }

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
    """Check if the memory is available and operational."""
    def is_available -> bool abs;

    """Retrieve an anchor by its UUID."""
    def get(id: UUID) -> (Anchor | None) abs;

    """Store an anchor."""
    def put(anchor: Anchor) -> None abs;

    """Remove an anchor by ID."""
    def delete(id: UUID) -> None abs;

    """Close the memory and release resources."""
    def close -> None abs;

    """Check if an anchor is currently in memory."""
    def has(id: UUID) -> bool abs;

    """Query all anchors with optional filter."""
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None] abs;

    """Get all root anchors."""
    def get_roots -> Generator[Root, None, None] abs;

    """Find anchors by IDs with optional filter."""
    def find(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None] abs;

    """Find one anchor by ID(s) with optional filter."""
    def find_one(
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None) abs;

    """Commit/sync pending changes. For write-through this flushes to durable storage."""
    def commit(anchor: (Anchor | None) = None) -> None abs;
}

"""Cache Memory Interface.

Extends Memory with operations specific to ephemeral caching.
Cache backends are expected to be fast but data loss is acceptable.
Used for L2 (local or distributed cache like Redis) in the tiered hierarchy.
"""
obj CacheMemory(Memory) {
    """Check if a key exists in the cache without loading the value."""
    def exists(id: UUID) -> bool abs;

    """Store an anchor only if it already exists in the cache."""
    def put_if_exists(anchor: Anchor) -> bool abs;

    """Invalidate a cache entry by ID."""
    def invalidate(id: UUID) -> None abs;
}

"""Persistent Memory Interface.

Extends Memory with operations specific to durable storage.
Implementations must guarantee data durability after sync().
"""
obj PersistentMemory(Memory) {
    """Flush pending writes to durable storage."""
    def sync -> None abs;

    """Bulk store multiple anchors efficiently."""
    def bulk_put(anchors: Iterable[Anchor]) -> None abs;
}

# =============================================================================
# Concrete Implementations
# =============================================================================
"""Volatile Memory - Simple in-memory storage with no persistence.

This is the L1 tier in a tiered memory hierarchy. All data is lost when
the process exits. Used as the fast cache layer in TieredMemory.
"""
obj VolatileMemory(Memory) {
    has __mem__: dict[UUID, Anchor] = {},
        __gc__: set[Anchor] = {};

    def postinit -> None;
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
    # Additional methods for garbage collection tracking
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
        __mem__: dict[UUID, Anchor] = {},
        __gc__: set[Anchor] = {},
        __conn__: (sqlite3.Connection | None) = None;

    def postinit -> None;
    # Lazy connection initialization - DB only created when data is written
    def _ensure_connection -> None;
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
        l2: (CacheMemory | None) = None,
        l3: (PersistentMemory | None) = None,
        use_cache: bool = False;

    def postinit -> None;
    # Override only methods that need tiering logic
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def has(id: UUID) -> bool;
    def commit(anchor: (Anchor | None) = None) -> None;
}
