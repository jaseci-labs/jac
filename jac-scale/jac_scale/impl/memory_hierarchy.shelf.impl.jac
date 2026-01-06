"""Shelf PersistenceBackend Implementation."""
import os;
import shelve;
import dbm.dumb;
import from threading { RLock }
import from typing { cast }
import from collections.abc { Iterable, MutableMapping }
import from uuid { UUID }
import from jaclang.pycore.archetype { Anchor }
import logging;
import from jaclang.runtimelib.storage { AnchorMergeStrategy }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);


"""Post-initialization: set up threading lock."""
impl ShelfBackend.postinit -> None {
    self._lock = RLock();
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
            del (shelf[key], );
            shelf.sync();
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
