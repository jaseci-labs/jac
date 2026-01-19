"""Memory Hierarchy Implementations.

Implementations for VolatileMemory, LocalCacheMemory, SqliteMemory, and TieredMemory.
"""

import logging;
import os;
import sqlite3;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from typing { cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }

glob logger = logging.getLogger(__name__);

# =============================================================================
# VolatileMemory Implementation (L1)
# =============================================================================
"""Initialize mutable defaults."""
impl VolatileMemory.postinit -> None {
    self.__mem__ = {};
    self.__gc__ = set();
}

"""In-memory storage is always available."""
impl VolatileMemory.is_available -> bool {
    return True;
}

"""Retrieve an anchor by ID."""
impl VolatileMemory.get(id: UUID) -> (Anchor | None) {
    return self.__mem__.get(id);
}

"""Store an anchor."""
impl VolatileMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
}

"""Remove an anchor by ID and track for garbage collection."""
impl VolatileMemory.delete(id: UUID) -> None {
    if (anchor := self.__mem__.pop(id, None)) {
        self.__gc__.add(anchor);
    }
}

"""Close and clear memory."""
impl VolatileMemory.close -> None {
    self.__mem__.clear();
    self.__gc__.clear();
}

"""Check if an anchor is in memory."""
impl VolatileMemory.has(id: UUID) -> bool {
    return id in self.__mem__;
}

"""Query all anchors with optional filter."""
impl VolatileMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

"""Get all root anchors."""
impl VolatileMemory.get_roots -> Generator[Root, None, None] {
    for anchor in self.__mem__.values() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl VolatileMemory.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.__mem__.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl VolatileMemory.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.__mem__.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Get garbage collection list."""
impl VolatileMemory.get_gc -> list[Anchor] {
    return list(self.__gc__);
}

"""Remove anchor from garbage collection list."""
impl VolatileMemory.remove_from_gc(anchor: Anchor) -> None {
    self.__gc__.discard(anchor);
}

"""Get the underlying memory dict."""
impl VolatileMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

"""Commit - no-op for volatile memory."""
impl VolatileMemory.commit(anchor: (Anchor | None) = None) -> None {
# No persistence, nothing to commit
}

# =============================================================================
# LocalCacheMemory Implementation (L2)
# Inherits all Memory interface methods from VolatileMemory.
# Only implements CacheMemory-specific methods.
# =============================================================================
"""Check if a key exists in the cache without loading the value."""
impl LocalCacheMemory.exists(id: UUID) -> bool {
    return id in self.__mem__;
}

"""Store an anchor only if it already exists in the cache."""
impl LocalCacheMemory.put_if_exists(anchor: Anchor) -> bool {
    if anchor.id in self.__mem__ {
        self.__mem__[anchor.id] = anchor;
        return True;
    }
    return False;
}

"""Invalidate a cache entry by ID."""
impl LocalCacheMemory.invalidate(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

# =============================================================================
# SqliteMemory Implementation (L3 Persistent)
# =============================================================================
"""Initialize SqliteMemory with a file path (lazy - no DB created yet)."""
impl SqliteMemory.postinit -> None {
    self.__mem__ = {};
    self.__gc__ = set();
    # Connection is lazily initialized on first write
    self.__conn__ = None;
}

"""Lazily initialize SQLite connection when first needed."""
impl SqliteMemory._ensure_connection -> None {
    if self.__conn__ is not None {
        return;
    }
    # Ensure parent directory exists for database file
    parent_dir = os.path.dirname(self.path);
    if parent_dir {
        os.makedirs(parent_dir, exist_ok=True);
    }
    # Open SQLite connection with WAL mode for better concurrency
    self.__conn__ = sqlite3.connect(self.path, check_same_thread=False);
    self.__conn__.execute("PRAGMA journal_mode=WAL");
    self.__conn__.execute("PRAGMA synchronous=NORMAL");
    # Create anchors table if it doesn't exist
    self.__conn__.execute(
        """
        CREATE TABLE IF NOT EXISTS anchors (
            id TEXT PRIMARY KEY,
            data BLOB NOT NULL
        )
    """
    );
    self.__conn__.commit();
}

"""Check if database connection is available."""
impl SqliteMemory.is_available -> bool {
    return self.__conn__ is not None;
}

"""Get an anchor by ID. Check memory first, then database."""
impl SqliteMemory.get(id: UUID) -> (Anchor | None) {
    import from _pickle { UnpicklingError }
    # Check in-memory cache first
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }
    # Lazily connect if DB file exists (for reading existing data)
    if not self.__conn__ and os.path.exists(self.path) {
        self._ensure_connection();
    }
    # Check database
    if self.__conn__ {
        cursor = self.__conn__.execute(
            "SELECT data FROM anchors WHERE id = ?", (str(id), )
        );
        if (row := cursor.fetchone()) {
            try {
                anchor = loads(row[0]);
                # Promote to memory cache
                self.__mem__[id] = anchor;
                return anchor;
            } except (UnpicklingError, ModuleNotFoundError, AttributeError) {
                # Can't unpickle - likely stale data from previous session
                # Delete the stale entry
                self.__conn__.execute("DELETE FROM anchors WHERE id = ?", (str(id), ));
                self.__conn__.commit();
                return None;
            }
        }
    }
    return None;
}

"""Store an anchor. Writes to memory immediately, database on sync."""
impl SqliteMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
}

"""Delete an anchor and track for garbage collection (only if persistent)."""
impl SqliteMemory.delete(id: UUID) -> None {
    if (anchor := self.__mem__.pop(id, None)) {
        # Only track persistent anchors for DB deletion
        if anchor.persistent {
            self.__gc__.add(anchor);
        }
    }
    # Also remove from database immediately if connected
    if self.__conn__ {
        self.__conn__.execute("DELETE FROM anchors WHERE id = ?", (str(id), ));
        self.__conn__.commit();
    }
}

"""Close database connection and clear memory."""
impl SqliteMemory.close -> None {
    if self.__conn__ {
        self.__conn__.close();
        self.__conn__ = None;
    }
    self.__mem__.clear();
    self.__gc__.clear();
}

"""Check if an anchor is in memory or database."""
impl SqliteMemory.has(id: UUID) -> bool {
    if id in self.__mem__ {
        return True;
    }
    # Lazily connect if DB file exists
    if not self.__conn__ and os.path.exists(self.path) {
        self._ensure_connection();
    }
    if self.__conn__ {
        cursor = self.__conn__.execute(
            "SELECT 1 FROM anchors WHERE id = ?", (str(id), )
        );
        return cursor.fetchone() is not None;
    }
    return False;
}

"""Query all anchors with optional filter."""
impl SqliteMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

"""Get all root anchors."""
impl SqliteMemory.get_roots -> Generator[Root, None, None] {
    for anchor in self.__mem__.values() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl SqliteMemory.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl SqliteMemory.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Sync memory to database with access control checks."""
impl SqliteMemory.sync -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    import from _pickle { PicklingError }
    # Check if there's anything to sync
    has_persistent = any(a.persistent for a in self.__mem__.values());
    if not self.__gc__ and not has_persistent {
        return;  # Nothing to sync, don't create DB

    }
    # Lazily create connection now that we have data to persist
    self._ensure_connection();
    # Handle garbage collected anchors (deletions)
    for anchor in self.__gc__ {
        self.__conn__.execute("DELETE FROM anchors WHERE id = ?", (str(anchor.id), ));
    }
    self.__gc__.clear();
    # Sync memory to database with access control
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent {
            continue;
        }

        key = str(id);
        try {
            cursor = self.__conn__.execute(
                "SELECT data FROM anchors WHERE id = ?", (key, )
            );
            row = cursor.fetchone();
            stored = loads(row[0]) if row else None;

            if stored {
                # Handle edge updates (CONNECT access)
                if (
                    isinstance(stored, NodeAnchor)
                    and isinstance(anchor, NodeAnchor)
                    and stored.edges != anchor.edges
                    and Jac.check_connect_access(anchor)
                ) {
                    if not anchor.edges and not isinstance(anchor.archetype, Root) {
                        self.__conn__.execute(
                            "DELETE FROM anchors WHERE id = ?", (key, )
                        );
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
                self.__conn__.execute(
                    "INSERT OR REPLACE INTO anchors (id, data) VALUES (?, ?)",
                    (key, dumps(stored))
                );
            } elif not (
                isinstance(anchor, NodeAnchor)
                and not isinstance(anchor.archetype, Root)
                and not anchor.edges
            ) {
                # New anchor - check write access before persisting
                if Jac.check_write_access(anchor) {
                    self.__conn__.execute(
                        "INSERT OR REPLACE INTO anchors (id, data) VALUES (?, ?)",
                        (key, dumps(anchor))
                    );
                }
            }
        } except (PicklingError, AttributeError, ModuleNotFoundError) {
            # Skip anchors that can't be pickled (e.g., transient test classes)
            continue;
        }
    }
    self.__conn__.commit();
}

"""Bulk store multiple anchors."""
impl SqliteMemory.bulk_put(anchors: Iterable[Anchor]) -> None {
    for anchor in anchors {
        self.put(anchor);
    }
}

"""Get garbage collection list."""
impl SqliteMemory.get_gc -> list[Anchor] {
    return list(self.__gc__);
}

"""Remove anchor from garbage collection list."""
impl SqliteMemory.remove_from_gc(anchor: Anchor) -> None {
    self.__gc__.discard(anchor);
}

"""Get the underlying memory dict."""
impl SqliteMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

"""Commit - syncs pending changes to database."""
impl SqliteMemory.commit(anchor: (Anchor | None) = None) -> None {
    self.sync();
}

# =============================================================================
# TieredMemory Implementation (extends VolatileMemory with L2 + L3)
# Inherits L1 functionality (__mem__, __gc__) from VolatileMemory.
# Only overrides methods that need tiering logic.
# =============================================================================
"""Initialize TieredMemory with optional cache and persistence."""
impl TieredMemory.postinit -> None {
    import from jaclang.runtimelib.memory { LocalCacheMemory, SqliteMemory }
    # Initialize L1 (inherited from VolatileMemory)
    self.__mem__ = {};
    self.__gc__ = set();
    # Initialize L2 cache if requested
    if self.use_cache {
        self.l2 = LocalCacheMemory();
    } else {
        self.l2 = None;
    }
    # Initialize L3 persistence if base_path provided
    if self.base_path {
        db_path = os.path.join(self.base_path, ".jac", "data", "main.db");
        self.l3 = SqliteMemory(path=db_path);
    } else {
        self.l3 = None;
    }
}

"""Get anchor with read-through: L1 -> L2 -> L3 with promotion."""
impl TieredMemory.get(id: UUID) -> (Anchor | None) {
    # L1 hit (self.__mem__ inherited from VolatileMemory)
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }
    # L2 hit with promotion to L1
    if self.l2 and (anchor := self.l2.get(id)) {
        self.__mem__[anchor.id] = anchor;
        return anchor;
    }
    # L3 fallback with promotion to L1 (and L2 if enabled)
    if self.l3 and (anchor := self.l3.get(id)) {
        self.__mem__[anchor.id] = anchor;
        if self.l2 {
            self.l2.put(anchor);
        }
        return anchor;
    }
    return None;
}

"""Put anchor with write-through: L1 always, L2/L3 with access control."""
impl TieredMemory.put(anchor: Anchor) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    # Always write to L1 (self.__mem__ inherited from VolatileMemory)
    self.__mem__[anchor.id] = anchor;
    # Write-through to L2 (cache) if enabled
    if self.l2 {
        self.l2.put(anchor);
    }
    # Write-through to L3 with access control check
    if self.l3 and anchor.persistent {
        if Jac.check_write_access(anchor) {
            self.l3.put(anchor);
        }
    }
}

"""Delete anchor from all tiers."""
impl TieredMemory.delete(id: UUID) -> None {
    # Delete from L1 (only track persistent anchors for GC)
    if (anchor := self.__mem__.pop(id, None)) {
        if anchor.persistent {
            self.__gc__.add(anchor);
        }
    }
    # Invalidate L2 cache
    if self.l2 {
        self.l2.invalidate(id);
    }
    # Delete from L3 persistence (only if we have persistent data)
    if self.l3 {
        self.l3.delete(id);
    }
}

"""Close all tiers."""
impl TieredMemory.close -> None {
    # Sync L3 before closing
    if self.l3 {
        self.l3.sync();
        self.l3.close();
    }
    # Close L2
    if self.l2 {
        self.l2.close();
    }
    # Clear L1 (inherited from VolatileMemory)
    self.__mem__.clear();
    self.__gc__.clear();
}

"""Check if anchor exists in any tier."""
impl TieredMemory.has(id: UUID) -> bool {
    # Check L1 first
    if id in self.__mem__ {
        return True;
    }
    # Check L2 cache
    if self.l2 and self.l2.exists(id) {
        return True;
    }
    # Check L3 persistence
    if self.l3 and self.l3.has(id) {
        return True;
    }
    return False;
}

"""Commit - syncs L3 persistence if available."""
impl TieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 {
        self.l3.sync();
    }
}
