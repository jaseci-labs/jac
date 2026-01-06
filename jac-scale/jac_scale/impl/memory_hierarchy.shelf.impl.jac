"""Shelf PersistenceBackend Implementation."""
import os;
import shelve;
import dbm.dumb;
import logging;
import from collections.abc { Callable, Generator, Iterable, MutableMapping }
import from pickle { dumps }
import from threading { RLock }
import from typing { cast }
import from uuid { UUID }
import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);

"""Post-initialization: set up threading lock and init mutable defaults."""
impl ShelfBackend.postinit -> None {
    self._lock = RLock();
    self.__mem__ = {};
    self.__gc__ = set();
    # Don't open shelf immediately - lazy initialization
}

"""Check if Shelf backend is available (always true as fallback)."""
impl ShelfBackend.is_available -> bool {
    # Shelf is always available as a fallback (file-based)
    return True;
}

"""Get anchor by UUID from shelf."""
impl ShelfBackend.get(id: UUID) -> (Anchor | None) {
    key = storage_key(to_uuid(id));
    shelf = self._ensure_shelf();
    with self._lock {
        if key not in shelf {
            return None;
        }
        return shelf[key];
    }
}

"""Store anchor in shelf."""
impl ShelfBackend.put(anchor: Anchor) -> None {
    key = storage_key(anchor.id);
    shelf = self._ensure_shelf();
    with self._lock {
        shelf[key] = anchor;
        shelf.sync();
    }
}

"""Delete anchor from shelf."""
impl ShelfBackend.delete(id: UUID) -> None {
    key = storage_key(to_uuid(id));
    shelf = self._ensure_shelf();
    with self._lock {
        if key in shelf {
            del (shelf[key], ) ;
            shelf.sync();
        }
    }
}

"""Close shelf and release resources."""
impl ShelfBackend.close -> None {
    if self._shelf is not None {
        try {
            self._shelf.close();
        } except Exception as e {
            logger.warning(f"Error closing shelf: {e}");
        }
        self._shelf = None;
    }
    self.__mem__.clear();
    self.__gc__.clear();
}

"""Check if an anchor exists in shelf."""
impl ShelfBackend.has(id: UUID) -> bool {
    key = storage_key(to_uuid(id));
    shelf = self._ensure_shelf();
    with self._lock {
        return key in shelf;
    }
}

"""Query all anchors with optional filter."""
impl ShelfBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    shelf = self._ensure_shelf();
    with self._lock {
        for key in shelf.keys() {
            anchor = shelf[key];
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Get all root anchors."""
impl ShelfBackend.get_roots -> Generator[Root, None, None] {
    for anchor in self.query() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl ShelfBackend.find(
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
impl ShelfBackend.find_one(
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

"""Commit - syncs the shelf."""
impl ShelfBackend.commit(anchor: (Anchor | None) = None) -> None {
    self.sync();
}

# PersistentMemory specific methods
"""Sync - flush shelf to disk."""
impl ShelfBackend.sync -> None {
    if self._shelf is not None {
        with self._lock {
            self._shelf.sync();
        }
    }
}

"""Bulk store anchors in shelf."""
impl ShelfBackend.bulk_put(anchors: Iterable[Anchor]) -> None {
    shelf = self._ensure_shelf();
    with self._lock {
        for anchor in anchors {
            key = storage_key(anchor.id);
            shelf[key] = anchor;
        }
        shelf.sync();
    }
}

"""Get garbage collection list."""
impl ShelfBackend.get_gc -> list[Anchor] {
    return list(self.__gc__);
}

"""Remove anchor from garbage collection list."""
impl ShelfBackend.remove_from_gc(anchor: Anchor) -> None {
    self.__gc__.discard(anchor);
}

"""Get the underlying memory dict."""
impl ShelfBackend.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

"""Sync memory cache to shelf with access control merge strategy."""
impl ShelfBackend.sync_from_memory(
    memory: dict[UUID, Anchor], gc_set: set[Anchor]
) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    shelf = self._ensure_shelf();
    with self._lock {
        # Handle garbage collected anchors (deletions)
        for anchor in gc_set {
            key = storage_key(anchor.id);
            if key in shelf {
                del (shelf[key], ) ;
            }
        }
        # Sync memory to shelf with access control
        for (id, anchor) in memory.items() {
            if not anchor.persistent {
                continue;
            }

            key = storage_key(id);
            stored = shelf.get(key);

            if stored {
                # Handle edge updates (CONNECT access)
                if (
                    isinstance(stored, NodeAnchor)
                    and isinstance(anchor, NodeAnchor)
                    and stored.edges != anchor.edges
                    and Jac.check_connect_access(anchor)
                ) {
                    if not anchor.edges and not isinstance(anchor.archetype, Root) {
                        del (shelf[key], ) ;
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
                shelf[key] = stored;
            } elif not (
                isinstance(anchor, NodeAnchor)
                and not isinstance(anchor.archetype, Root)
                and not anchor.edges
            ) {
                shelf[key] = anchor;
            }
        }
        shelf.sync();
    }
}

"""Ensure shelf is opened, lazy initialization."""
impl ShelfBackend._ensure_shelf -> shelve.Shelf {
    if self._shelf is None {
        # Ensure parent directory exists
        parent_dir = os.path.dirname(self.shelf_path);
        if parent_dir {
            os.makedirs(parent_dir, exist_ok=True);
        }
        self._shelf = self._open_shelf();
    }
    return self._shelf;
}

"""Open shelf using dbm.dumb backend to avoid Linux gdbm locking issues."""
impl ShelfBackend._open_shelf -> shelve.Shelf {
    if self._shelf is None {
        raw_db = dbm.dumb.open(self.shelf_path, 'c');
        # Type annotation instead of cast to avoid generic type issues
        db_as_mapping: MutableMapping[(<>bytes, <>bytes)] = raw_db;
        self._shelf = shelve.Shelf(db_as_mapping, writeback=False);
    }
    return self._shelf;
}
