"""Memory management for Jac Language."""

import shelve;
import from collections.abc { Callable, Generator, Iterable }
import from dataclasses { dataclass, field }
import from pickle { dumps }
import from typing { Any, Generic, TypeVar, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { TANCH, Anchor, NodeAnchor, Root }

glob ID = TypeVar('ID'),
     __all__ = ['Memory', 'ShelfStorage'];

"""Generic Memory Handler."""
@dataclass
class Memory(Generic[ID, TANCH]) {
    has __mem__: dict[(ID | UUID), TANCH] = field(default_factory=dict),
        __gc__: set[TANCH] = field(default_factory=set);

    def close(self: Memory) -> None;
    def is_cached(self: Memory, id: ID) -> bool;
    def query(
        self: Memory, filter: (Callable[[TANCH], bool] | None) = None
    ) -> Generator[TANCH, None, None];

    def all_root(self: Memory) -> Generator[Root, None, None];
    def find(
        self: Memory,
        ids: (ID | Iterable[ID]),
        filter: (Callable[[TANCH], TANCH] | None) = None
    ) -> Generator[TANCH, None, None];

    def find_one(
        self: Memory,
        ids: (ID | Iterable[ID]),
        filter: (Callable[[TANCH], TANCH] | None) = None
    ) -> (TANCH | None);

    def find_by_id(self: Memory, id: ID) -> (TANCH | None);
    def set(self: Memory, data: TANCH) -> None;
    def remove(self: Memory, ids: (ID | Iterable[ID])) -> None;
    def commit(self: Memory, anchor: (TANCH | None) = None) -> None;
    def get_gc(self: Memory) -> list[TANCH];
    def remove_from_gc(self: Memory, anchor: TANCH) -> None;
    def get_mem(self: Memory) -> dict[(ID | UUID), TANCH];
    def remove_from_mem(self: Memory, anchor: (ID | UUID)) -> None;
}

"""Shelf Handler."""
@dataclass
class ShelfStorage(Memory[UUID, Anchor]) {
    has __shelf__: (shelve.Shelf[Anchor] | None) = None;

    def init(self: ShelfStorage, session: (str | None) = None) -> None;
    def commit(self: ShelfStorage, anchor: (Anchor | None) = None) -> None;
    def close(self: ShelfStorage) -> None;
    def sync_mem_to_db(self: ShelfStorage, keys: Iterable[UUID]) -> None;
    def query(
        self: ShelfStorage, filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Any, None, None];

    def find(
        self: ShelfStorage,
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_by_id(self: ShelfStorage, id: UUID) -> (Anchor | None);
}
