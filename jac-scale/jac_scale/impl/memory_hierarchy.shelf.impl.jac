"""Commit one or many anchors."""

impl ShelfDB.commit(
    anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []
) -> None {
    if anchor {
        self.set(anchor);
        return;
    }
    for anc in keys {
        self.set(anc);
    }
}

impl ShelfDB.find_by_id(id: UUID) -> (Anchor | None) {
    _id = self._to_uuid(id);
    return self._load_anchor_from_shelf(_id);
}

"""Remove anchor from shelf."""
impl ShelfDB.remove(anchor: Anchor) -> None {
    key = self._redis_key(anchor.id);
    shelf = self._ensure_shelf();
    with self._lock {
        if (key in shelf) {
            del (shelf[key], ) ;
            shelf.sync();
        }
    }
}

"""Save anchor to shelf."""
impl ShelfDB.<>set(anchor: Anchor) -> None {
    key = self._redis_key(anchor.id);
    shelf = self._ensure_shelf();
    with self._lock {
        shelf[key] = anchor;
        shelf.sync();
    }
}

impl ShelfDB._load_anchor_from_shelf(id: UUID) -> (Anchor | None) {
    key = self._redis_key(id);
    shelf = self._ensure_shelf();
    with self._lock {
        if (key not in shelf) {
            return None;
        }
        return shelf[key];
    }
}

impl ShelfDB._to_uuid(id: (UUID | str)) -> UUID {
    if not isinstance(id, UUID) {
        return UUID(str(id));
    }
    return id;
}

"""Match key format used by Redis for consistency."""
impl ShelfDB._redis_key(id: UUID) -> str {
    return f"anchor:{str(id)}";
}

"""Cleanly close shelf storage."""
impl ShelfDB.close{
    if (self._shelf is not None) {
        self._shelf.close();
        self._shelf = None;
    }
}

impl ShelfDB._ensure_shelf -> shelve.Shelf {
    if (self._shelf is None) {
        # Ensure parent directory exists
        import os;
        parent_dir = os.path.dirname(self.shelf_path);
        if parent_dir {
            os.makedirs(parent_dir, exist_ok=True);
        }
        self._shelf = self._open_shelf();
    }
    return self._shelf;
}

"""Always use dbm.dumb backend to avoid Linux gdbm locking."""
impl ShelfDB._open_shelf -> shelve.Shelf {
    import dbm.dumb;
    if (self._shelf is None) {
        raw_db = dbm.dumb.open(self.shelf_path, 'c');
        db_as_mapping = cast(MutableMapping[(<>bytes, <>bytes)], raw_db);
        self._shelf = shelve.Shelf(db_as_mapping, writeback=False);
    }
    return self._shelf;
}

"""Initialize shelf DB on startup."""
impl ShelfDB.postinit{
    self._lock = RLock();
    self._open_shelf();
}
