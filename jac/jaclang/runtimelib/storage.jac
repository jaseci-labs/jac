"""Storage Backend Protocols for Jac Language.

This module defines the type-safe interface hierarchy for storage backends:
- DataBackend: Base protocol for all storage operations
- CacheBackend: Extended protocol for cache-specific operations
- PersistenceBackend: Extended protocol for durable storage operations

These protocols enable a unified multi-tier storage architecture where
different backends can be composed (e.g., Memory + Redis + MongoDB).
"""

import logging;
import shelve;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from uuid { UUID }
import from typing { Any }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.memory { Memory }

glob logger = logging.getLogger(__name__),
     __all__ = [
         'DataBackend',
         'CacheBackend',
         'PersistenceBackend',
         'AnchorMergeStrategy',
         'ShelfStorage',
         'MemoryOrchestrator'
     ];

"""
Base protocol for all storage backends.

Provides the minimal interface that all storage tiers must implement.
This enables uniform handling of in-memory, cache, and persistence layers.
"""
obj DataBackend {
    """Check if the backend is available and connected."""
    def is_available -> bool abs;

    """Retrieve an anchor by its UUID."""
    def get(id: UUID) -> (Anchor | None) abs;

    """Store an anchor."""
    def put(anchor: Anchor) -> None abs;

    """Remove an anchor from storage by ID."""
    def delete(id: UUID) -> None abs;

    """Close the backend connection and release resources."""
    def close -> None abs;
}

"""
Cache-specific backend protocol.

Extends DataBackend with operations specific to caching semantics.
Cache backends are expected to be fast but ephemeral - data loss is acceptable.
"""
obj CacheBackend(DataBackend) {
    """Check if a key exists in the cache without loading the value."""
    def exists(id: UUID) -> bool abs;

    """Store an anchor only if it already exists in the cache.
    Returns True if the anchor was stored, False if the key didn't exist."""
    def put_if_exists(anchor: Anchor) -> bool abs;

    """Invalidate a cache entry by ID."""
    def invalidate(id: UUID) -> None abs;
}

"""
Persistence-specific backend protocol.

Extends DataBackend with operations specific to durable storage semantics.
Persistence backends must guarantee data durability - data loss is a failure.
"""
obj PersistenceBackend(DataBackend) {
    """Bulk store multiple anchors efficiently."""
    def bulk_put(anchors: Iterable[Anchor]) -> None abs;
}

"""
Utility for merging anchors with access control.

Extracts the common logic for CONNECT and WRITE permission handling
that was previously duplicated across storage implementations.
"""
obj AnchorMergeStrategy {
    static def merge(incoming: Anchor, stored: (Anchor | None)) -> Anchor;
    static def needs_persist(anchor: Anchor) -> bool;
    static def serialize(anchor: Anchor) -> (bytes | None);
    static def deserialize(data: bytes) -> (Anchor | None);
}

"""
Shelf-based persistence backend.

Implements PersistenceBackend using Python's shelve module for
file-based durable storage. Used for local persistence scenarios.
"""
obj ShelfStorage(PersistenceBackend) {
    has __shelf__: (shelve.Shelf[Anchor] | None) = None,
        __path__: (str | None) = None;

    def init(path: str) -> None;
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def bulk_put(anchors: Iterable[Anchor]) -> None;
    def sync_from_memory(memory: dict[UUID, Anchor], gc_set: set[Anchor]) -> None;
    def load_all(memory: dict[UUID, Anchor]) -> None;
}

"""
Base Storage Orchestrator - coordinates memory and persistence layers.

This is the base class providing L1 (Memory) + L3 (Persistence) coordination.
jac-scale extends this to add L2 (distributed cache like Redis).

Uses pure composition - contains a Memory instance rather than inheriting.
Provides a Memory-compatible interface so ExecutionContext can use it as its single
storage abstraction.
"""
class MemoryOrchestrator {
    has memory: Memory[(UUID, Anchor)],
        persistence: (PersistenceBackend | None) = None;

    def init(
        self: MemoryOrchestrator, persistence: (PersistenceBackend | None) = None
    ) -> None;

    # Core storage operations (with read-through caching)
    def is_available(self: MemoryOrchestrator) -> bool;
    def get(self: MemoryOrchestrator, id: UUID) -> (Anchor | None);
    def put(self: MemoryOrchestrator, anchor: Anchor) -> None;
    def delete(self: MemoryOrchestrator, id: UUID) -> None;
    def close(self: MemoryOrchestrator) -> None;
    # Memory-compatible query interface
    def is_cached(self: MemoryOrchestrator, id: UUID) -> bool;
    def query(
        self: MemoryOrchestrator, filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def all_root(self: MemoryOrchestrator) -> Generator[Root, None, None];
    def find(
        self: MemoryOrchestrator,
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        self: MemoryOrchestrator,
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    # Commit and garbage collection
    def commit(self: MemoryOrchestrator, anchor: (Anchor | None) = None) -> None;
    def get_gc(self: MemoryOrchestrator) -> list[Anchor];
    def remove_from_gc(self: MemoryOrchestrator, anchor: Anchor) -> None;
    def get_mem(self: MemoryOrchestrator) -> dict[(UUID, Anchor)];
    def remove_from_mem(self: MemoryOrchestrator, anchor: UUID) -> None;
    # Internal backend coordination
    def _sync_to_backends(self: MemoryOrchestrator, anchors: Iterable[Anchor]) -> None;
    def _delete_from_backends(self: MemoryOrchestrator, id: UUID) -> None;
}
