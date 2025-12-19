"""Find one by id."""

impl ShelfStorage.find_by_id(self: ShelfStorage, id: UUID) -> (Anchor | None) {
    data = super.find_by_id(id);
    if (
        not data
        and isinstance(self.__shelf__, Shelf)
        and (data := self.__shelf__.get(str(id)))
    ) {
        self.__mem__[id] = data;
    }
    return data;
}

"""Find anchors from datasource by ids with filter."""
impl ShelfStorage.find(
    self: ShelfStorage,
    ids: (UUID | Iterable[UUID]),
    filter: (Callable[([Anchor], Anchor)] | None) = None
) -> Generator[Anchor] {
    if not isinstance(ids, Iterable) {
        ids = [ids];
    }
    if isinstance(self.__shelf__, Shelf) {
        for id in ids {
            anchor = self.__mem__.get(id);
            if (
                not anchor
                and (id not in self.__gc__)
                and (_anchor := self.__shelf__.get(str(id)))
            ) {
                self.__mem__[id] = anchor=_anchor;
            }
            if (anchor and (not filter or filter(anchor))) {
                yield anchor;
                ;
            }
        }
    } else {
        yield from super.find(ids, filter);
        ;
    }
}

"""Find anchors from memory with filter."""
impl ShelfStorage.query(
    self: ShelfStorage, filter: (Callable[([Anchor], bool)] | None) = None
) -> Generator[Any] {
    if isinstance(self.__shelf__, Shelf) {
        for anchor in self.__shelf__.values() {
            if (not filter or filter(anchor)) {
                if (anchor.id not in self.__mem__) {
                    self.__mem__[anchor.id] = anchor;
                }
                yield anchor;
                ;
            }
        }
    } else {
        yield from super.query(filter);
        ;
    }
}

"""Manually sync memory to db."""
impl ShelfStorage.sync_mem_to_db(self: ShelfStorage, keys: Iterable[UUID]) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    if isinstance(self.__shelf__, Shelf) {
        for key in keys {
            if (
                (d := self.__mem__.get(key))
                and d.persistent
                and (d.hash != hash(dumps(d)))
            ) {
                _id = str(d.id);
                if (p_d := self.__shelf__.get(_id)) {
                    if (
                        isinstance(p_d, NodeAnchor)
                        and isinstance(d, NodeAnchor)
                        and (p_d.edges != d.edges)
                        and Jac.check_connect_access(d)
                    ) {
                        if (not d.edges and not isinstance(d.archetype, Root)) {
                            self.__shelf__.pop(_id, None);
                            continue;
                        }
                        p_d.edges = d.edges;
                    }
                    if Jac.check_write_access(d) {
                        if (hash(dumps(p_d.access)) != hash(dumps(d.access))) {
                            p_d.access = d.access;
                        }
                        if (hash(dumps(p_d.archetype)) != hash(dumps(d.archetype))) {
                            p_d.archetype = d.archetype;
                        }
                    }
                    self.__shelf__[_id] = p_d;
                } elif not (
                    isinstance(d, NodeAnchor)
                    and not isinstance(d.archetype, Root)
                    and not d.edges
                ) {
                    self.__shelf__[_id] = d;
                }
            }
        }
    }
}

"""Close memory handler."""
impl ShelfStorage.close(self: ShelfStorage) -> None {
    self.commit();
    if isinstance(self.__shelf__, Shelf) {
        self.__shelf__.close();
    }
    super.close();
}

"""Commit all data from memory to datasource."""
impl ShelfStorage.commit(self: ShelfStorage, anchor: (Anchor | None) = None) -> None {
    if isinstance(self.__shelf__, Shelf) {
        if anchor {
            if (anchor in self.__gc__) {
                self.__shelf__.pop(str(anchor.id), None);
                self.__mem__.pop(anchor.id, None);
                self.__gc__.remove(anchor);
            } else {
                self.sync_mem_to_db([anchor.id]);
            }
            return;
        }
        for anc in self.__gc__ {
            self.__shelf__.pop(str(anc.id), None);
            self.__mem__.pop(anc.id, None);
        }
        keys = <>set(self.__mem__.keys());
        self.sync_mem_to_db(keys);
        self.sync_mem_to_db(<>set((self.__mem__.keys() - keys)));
    }
}

"""Initialize memory handler."""
impl ShelfStorage.init(self: ShelfStorage, session: (str | None) = None) -> None {
    super.init();
    self.__shelf__ = open(session) if session else None;
}

"""Commit all data from memory to datasource."""
impl Memory.remove_from_mem(self: Memory, anchor: (ID | UUID)) -> None {
    self.__mem__.pop(anchor);
}

"""Commit all data from memory to datasource."""
impl Memory.get_mem(self: Memory) -> <>dict {
    return self.__mem__;
}

"""Commit all data from memory to datasource."""
impl Memory.remove_from_gc(self: Memory, anchor: TANCH) -> None {
    self.__gc__.remove(anchor);
}

"""Commit all data from memory to datasource."""
impl Memory.get_gc(self: Memory) -> <>list {
    return <>list(self.__gc__);
}

"""Remove anchor/s from memory."""
impl Memory.remove(self: Memory, ids: (ID | Iterable[ID])) -> None {
    if not isinstance(ids, Iterable) {
        ids = [ids];
    }
    for id in ids {
        if (anchor := self.__mem__.pop(id, None)) {
            self.__gc__.add(anchor);
        }
    }
}

"""Save anchor to memory."""
impl Memory.<>set(self: Memory, data: TANCH) -> None {
    self.__mem__[data.id] = data;
}

"""Find one by id."""
impl Memory.find_by_id(self: Memory, id: ID) -> (TANCH | None) {
    return self.__mem__.get(id);
}

"""Find one anchor from memory by ids with filter."""
impl Memory.find_one(
    self: Memory,
    ids: (ID | Iterable[ID]),
    filter: (Callable[([TANCH], TANCH)] | None) = None
) -> (TANCH | None) {
    return next(self.find(ids, filter), None);
}

"""Find anchors from memory by ids with filter."""
impl Memory.find(
    self: Memory,
    ids: (ID | Iterable[ID]),
    filter: (Callable[([TANCH], TANCH)] | None) = None
) -> Generator[TANCH] {
    if not isinstance(ids, Iterable) {
        ids = [ids];
    }
    return (
        anchor
        for id in ids
        if ((anchor := self.__mem__.get(id)) and (not filter or filter(anchor)))
    );
}

"""Get all the roots."""
impl Memory.all_root(self: Memory) -> Generator[Root] {
    for anchor in self.query(lambda  anchor: Any: isinstance(anchor.archetype, Root)) {
        yield cast(Root, anchor.archetype);
        ;
    }
}

"""Find anchors from memory with filter."""
impl Memory.query(
    self: Memory, filter: (Callable[([TANCH], bool)] | None) = None
) -> Generator[TANCH] {
    return (
        anchor
        for anchor in self.__mem__.values()
        if (not filter or filter(anchor))
    );
}

"""Check if id if already cached."""
impl Memory.is_cached(self: Memory, id: ID) -> bool {
    return (id in self.__mem__);
}

"""Close memory handler."""
impl Memory.close(self: Memory) -> None {
    self.__mem__.clear();
    self.__gc__.clear();
}
