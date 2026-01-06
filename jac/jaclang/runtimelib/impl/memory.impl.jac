"""Memory management implementations."""

import from collections.abc { Callable, Generator, Iterable }
import from typing { cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { TANCH, Root }

"""In-memory storage is always available."""
impl Memory.is_available(self: Memory) -> bool {
    return True;
}

"""Retrieve an anchor by ID (DataBackend.get)."""
impl Memory.get(self: Memory, id: ID) -> (TANCH | None) {
    return self.__mem__.get(id);
}

"""Store an anchor (DataBackend.put)."""
impl Memory.put(self: Memory, data: TANCH) -> None {
    self.__mem__[data.id] = data;
}

"""Remove an anchor by ID and track for garbage collection."""
impl Memory.delete(self: Memory, id: ID) -> None {
    if (anchor := self.__mem__.pop(id, None)) {
        self.__gc__.add(anchor);
    }
}

"""Close memory handler and clear all data."""
impl Memory.close(self: Memory) -> None {
    self.__mem__.clear();
    self.__gc__.clear();
}

"""Check if id is already cached."""
impl Memory.is_cached(self: Memory, id: ID) -> bool {
    return id in self.__mem__;
}

"""Find anchors from memory with filter."""
impl Memory.query(
    self: Memory, filter: (Callable[[TANCH], bool] | None) = None
) -> Generator[TANCH, None, None] {
    return (
        anchor
        for anchor in self.__mem__.values()
        if not filter or filter(anchor)
    );
}

"""Get all the roots."""
impl Memory.all_root(self: Memory) -> Generator[Root, None, None] {
    for anchor in self.query(lambda  anchor: bool: isinstance(anchor.archetype, Root)) {
        yield cast(Root, anchor.archetype);
    }
}

"""Find anchors from memory by ids with filter."""
impl Memory.find(
    self: Memory,
    ids: (ID | Iterable[ID]),
    filter: (Callable[[TANCH], TANCH] | None) = None
) -> Generator[TANCH, None, None] {
    if not isinstance(ids, Iterable) {
        ids = [ids];
    }
    return (
        anchor
        for id in ids
        if (anchor := self.__mem__.get(id)) and (not filter or filter(anchor))
    );
}

"""Find one anchor from memory by ids with filter."""
impl Memory.find_one(
    self: Memory,
    ids: (ID | Iterable[ID]),
    filter: (Callable[[TANCH], TANCH] | None) = None
) -> (TANCH | None) {
    return next(self.find(ids, filter), None);
}

"""Commit all data from memory to datasource."""
impl Memory.commit(self: Memory, anchor: (TANCH | None) = None) -> None {
    pass;
}

"""Get garbage collection list."""
impl Memory.get_gc(self: Memory) -> list[TANCH] {
    return list(self.__gc__);
}

"""Remove from garbage collection."""
impl Memory.remove_from_gc(self: Memory, anchor: TANCH) -> None {
    self.__gc__.remove(anchor);
}

"""Get memory dict."""
impl Memory.get_mem(self: Memory) -> dict[(ID | UUID), TANCH] {
    return self.__mem__;
}

"""Remove from memory."""
impl Memory.remove_from_mem(self: Memory, anchor: (ID | UUID)) -> None {
    self.__mem__.pop(anchor);
}
