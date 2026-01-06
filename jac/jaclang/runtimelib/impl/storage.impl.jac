"""Storage implementations for ShelfStorage and MemoryOrchestrator."""

import logging;
import shelve;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from typing { cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.memory { Memory }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);

"""Merge an incoming anchor with a stored anchor, respecting access control."""
impl AnchorMergeStrategy.merge(incoming: Anchor, stored: (Anchor | None)) -> Anchor {
    import from jaclang { JacRuntimeInterface as Jac }
    if stored is None {
        return incoming;
    }
    working_anchor = incoming;
    # Handle CONNECT access - edge updates only for NodeAnchors
    if (
        isinstance(stored, NodeAnchor)
        and isinstance(incoming, NodeAnchor)
        and getattr(stored, 'edges', None) != getattr(incoming, 'edges', None)
        and Jac.check_connect_access(incoming)
    ) {
        stored.edges = incoming.edges;
        working_anchor = stored;
    }
    # Handle WRITE access - access and archetype updates
    if Jac.check_write_access(incoming) {
        try {
            if hash(dumps(stored.access)) != hash(dumps(incoming.access)) {
                stored.access = incoming.access;
            }
            if hash(dumps(stored.archetype)) != hash(dumps(incoming.archetype)) {
                stored.archetype = incoming.archetype;
            }
            working_anchor = stored;
        } except Exception as e {
            logger.warning(f"Failed to merge anchor access/archetype: {e}");
            working_anchor = incoming;
        }
    }
    return working_anchor;
}

"""Check if an anchor has changed by comparing its hash."""
impl AnchorMergeStrategy.needs_persist(anchor: Anchor) -> bool {
    try {
        current_hash = hash(dumps(anchor));
        return getattr(anchor, 'hash', None) != current_hash;
    } except Exception {
        # If we can't hash it, assume it needs persisting
        return True;
    }
}

"""Serialize an anchor for storage. Returns None if serialization fails."""
impl AnchorMergeStrategy.serialize(anchor: Anchor) -> (bytes | None) {
    try {
        return dumps(anchor);
    } except Exception as e {
        logger.warning(f"Failed to serialize anchor {anchor.id}: {e}");
        return None;
    }
}

"""Deserialize an anchor from storage. Returns None if deserialization fails."""
impl AnchorMergeStrategy.deserialize(data: bytes) -> (Anchor | None) {
    try {
        result = loads(data);
        if isinstance(result, Anchor) {
            anchor: Anchor = result;
            return anchor;
        }
        return None;
    } except Exception as e {
        logger.warning(f"Failed to deserialize anchor: {e}");
        return None;
    }
}

"""Initialize shelf storage with a file path."""
impl ShelfStorage.init(path: str) -> None {
    self.__path__ = path;
    self.__shelf__ = shelve.open(path);
}

"""Check if the shelf is available."""
impl ShelfStorage.is_available -> bool {
    return self.__shelf__ is not None;
}

"""Get an anchor by ID from shelf."""
impl ShelfStorage.get(id: UUID) -> (Anchor | None) {
    if isinstance(self.__shelf__, shelve.Shelf) {
        return self.__shelf__.get(str(id));
    }
    return None;
}

"""Store an anchor to shelf."""
impl ShelfStorage.put(anchor: Anchor) -> None {
    if isinstance(self.__shelf__, shelve.Shelf) {
        self.__shelf__[str(anchor.id)] = anchor;
    }
}

"""Delete an anchor from shelf."""
impl ShelfStorage.delete(id: UUID) -> None {
    if isinstance(self.__shelf__, shelve.Shelf) {
        self.__shelf__.pop(str(id), None);
    }
}

"""Close the shelf connection."""
impl ShelfStorage.close -> None {
    if isinstance(self.__shelf__, shelve.Shelf) {
        self.__shelf__.close();
        self.__shelf__ = None;
    }
}

"""Bulk store multiple anchors."""
impl ShelfStorage.bulk_put(anchors: Iterable[Anchor]) -> None {
    if isinstance(self.__shelf__, shelve.Shelf) {
        for anchor in anchors {
            self.__shelf__[str(anchor.id)] = anchor;
        }
    }
}

"""Sync memory cache to shelf with merge strategy."""
impl ShelfStorage.sync_from_memory(
    memory: dict[UUID, Anchor], gc_set: set[Anchor]
) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    import from jaclang.runtimelib.storage { AnchorMergeStrategy }
    if not isinstance(self.__shelf__, shelve.Shelf) {
        return;
    }
    # Handle garbage collected anchors
    for anchor in gc_set {
        self.__shelf__.pop(str(anchor.id), None);
    }
    # Sync memory to shelf - make a copy to avoid dict modification during iteration
    for (id, anchor) in list(memory.items()) {
        if not anchor.persistent {
            continue;
        }
        if not AnchorMergeStrategy.needs_persist(anchor) {
            continue;
        }

        _id = str(id);
        stored = self.__shelf__.get(_id);

        if stored {
            # Handle edge updates (CONNECT access)
            if (
                isinstance(stored, NodeAnchor)
                and isinstance(anchor, NodeAnchor)
                and stored.edges != anchor.edges
                and Jac.check_connect_access(anchor)
            ) {
                if not anchor.edges and not isinstance(anchor.archetype, Root) {
                    self.__shelf__.pop(_id, None);
                    continue;
                }
                stored.edges = anchor.edges;
            }
            # Handle access/archetype updates (WRITE access)
            if Jac.check_write_access(anchor) {
                if hash(dumps(stored.access)) != hash(dumps(anchor.access)) {
                    stored.access = anchor.access;
                }
                if hash(dumps(stored.archetype)) != hash(dumps(anchor.archetype)) {
                    stored.archetype = anchor.archetype;
                }
            }
            self.__shelf__[_id] = stored;
        } elif not (
            isinstance(anchor, NodeAnchor)
            and not isinstance(anchor.archetype, Root)
            and not anchor.edges
        ) {
            self.__shelf__[_id] = anchor;
        }
    }
}

"""Load all anchors from shelf into memory dict."""
impl ShelfStorage.load_all(memory: dict[UUID, Anchor]) -> None {
    if isinstance(self.__shelf__, shelve.Shelf) {
        for anchor in self.__shelf__.values() {
            if anchor.id not in memory {
                memory[anchor.id] = anchor;
            }
        }
    }
}

"""Initialize with Memory and optional persistence backend."""
impl MemoryOrchestrator.init(
    self: MemoryOrchestrator, persistence: (PersistenceBackend | None) = None
) -> None {
    import from jaclang.runtimelib.storage { PersistenceBackend }
    self.memory = Memory[(UUID, Anchor)]();
    self.persistence = persistence;
}

"""Retrieve anchor with read-through caching. L1 -> L3."""
impl MemoryOrchestrator.get(self: MemoryOrchestrator, id: UUID) -> (Anchor | None) {
    # L1: Check in-memory cache
    if (anchor := self.memory.get(id)) {
        return anchor;
    }
    # L3: Check persistence
    if self.persistence {
        if (anchor := self.persistence.get(id)) {
            # Promote to L1
            self.memory.put(anchor);
            return anchor;
        }
    }
    return None;
}

"""Store anchor in L1 memory cache."""
impl MemoryOrchestrator.put(self: MemoryOrchestrator, anchor: Anchor) -> None {
    self.memory.put(anchor);
}

"""Remove anchor by ID from L1 memory (persistence deletion happens on close via GC)."""
impl MemoryOrchestrator.delete(self: MemoryOrchestrator, id: UUID) -> None {
    # Ensure anchor is in L1 memory before deleting (so it can be tracked for GC)
    # This handles the case where we delete an edge that's only in persistence
    if not self.memory.is_cached(id) and self.persistence {
        if (anchor := self.persistence.get(id)) {
            self.memory.put(anchor);
        }
    }
    # Now delete from L1 memory and add to GC set
    # Persistence deletion happens on close() via sync_from_memory
    self.memory.delete(id);
}

"""Commit changes to persistence layer."""
impl MemoryOrchestrator.commit(
    self: MemoryOrchestrator, anchor: (Anchor | None) = None
) -> None {
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
impl MemoryOrchestrator.close(self: MemoryOrchestrator) -> None {
    import from jaclang.runtimelib.storage { ShelfStorage }
    # Use sync_from_memory for ShelfStorage (handles merge strategy)
    if isinstance(self.persistence, ShelfStorage) {
        self.persistence.sync_from_memory(
            self.memory.get_mem(), set(self.memory.get_gc())
        );
        self.persistence.close();
    } elif self.persistence {
        self.commit();
        self.persistence.close();
    }
    self.memory.close();
}

"""Get garbage collection list from memory."""
impl MemoryOrchestrator.get_gc(self: MemoryOrchestrator) -> list[Anchor] {
    return self.memory.get_gc();
}

"""Remove anchor from garbage collection list."""
impl MemoryOrchestrator.remove_from_gc(
    self: MemoryOrchestrator, anchor: Anchor
) -> None {
    self.memory.remove_from_gc(anchor);
}

"""Get memory dict."""
impl MemoryOrchestrator.get_mem(self: MemoryOrchestrator) -> dict[(UUID, Anchor)] {
    return self.memory.get_mem();
}

"""Sync anchors to persistence backend."""
impl MemoryOrchestrator._sync_to_backends(
    self: MemoryOrchestrator, anchors: Iterable[Anchor]
) -> None {
    anchor_list = list(anchors);
    try {
        # Write to persistence
        if self.persistence {
            self.persistence.bulk_put(anchor_list);
        }
    } except Exception as e {
        logger.error(f"Sync to backends failed: {e}");
    }
}

"""Delete anchor from persistence backend."""
impl MemoryOrchestrator._delete_from_backends(
    self: MemoryOrchestrator, id: UUID
) -> None {
    try {
        if self.persistence {
            self.persistence.delete(id);
        }
    } except Exception as e {
        logger.error(f"Delete from backends failed: {e}");
    }
}

"""Check if storage is available."""
impl MemoryOrchestrator.is_available(self: MemoryOrchestrator) -> bool {
    return self.memory.is_available();
}

"""Check if an anchor is cached in L1 memory."""
impl MemoryOrchestrator.is_cached(self: MemoryOrchestrator, id: UUID) -> bool {
    return self.memory.is_cached(id);
}

"""Query anchors from L1 memory with optional filter."""
impl MemoryOrchestrator.query(
    self: MemoryOrchestrator, filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    return self.memory.query(filter);
}

"""Get all root anchors from L1 memory."""
impl MemoryOrchestrator.all_root(
    self: MemoryOrchestrator
) -> Generator[Root, None, None] {
    return self.memory.all_root();
}

"""Find anchors by IDs from L1 memory with optional filter."""
impl MemoryOrchestrator.find(
    self: MemoryOrchestrator,
    ids: (UUID | Iterable[UUID]),
    filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    return self.memory.find(ids, filter);
}

"""Find one anchor by IDs from L1 memory with optional filter."""
impl MemoryOrchestrator.find_one(
    self: MemoryOrchestrator,
    ids: (UUID | Iterable[UUID]),
    filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    return self.memory.find_one(ids, filter);
}

"""Remove anchor from L1 memory."""
impl MemoryOrchestrator.remove_from_mem(self: MemoryOrchestrator, anchor: UUID) -> None {
    self.memory.remove_from_mem(anchor);
}
