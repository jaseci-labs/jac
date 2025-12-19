"""Core constructs for Jac Language."""
import from collections.abc { Callable, Generator, Iterable }
import from dataclasses { dataclass, field }
import from pickle { dumps }
import from shelve { Shelf, open }
import from typing { Any, Generic, TypeVar, cast }
import from uuid { UUID }
import from .archetype { TANCH, Anchor, NodeAnchor, Root }

glob ID = TypeVar('ID');

"""Generic Memory Handler."""
@dataclass
class Memory(Generic[(ID, TANCH)]) {
    with entry {
        __mem__: <>dict[((ID | UUID), TANCH)] = field(default_factory=<>dict);
        __gc__: <>set[TANCH] = field(default_factory=<>set);
    }

    def close(self: Memory) -> None;
    def is_cached(self: Memory, id: ID) -> bool;
    def query(
        self: Memory, filter: (Callable[([TANCH], bool)] | None) = None
    ) -> Generator[TANCH];

    def all_root(self: Memory) -> Generator[Root];
    def find(
        self: Memory,
        ids: (ID | Iterable[ID]),
        filter: (Callable[([TANCH], TANCH)] | None) = None
    ) -> Generator[TANCH];

    def find_one(
        self: Memory,
        ids: (ID | Iterable[ID]),
        filter: (Callable[([TANCH], TANCH)] | None) = None
    ) -> (TANCH | None);

    def find_by_id(self: Memory, id: ID) -> (TANCH | None);
    def <>set(self: Memory, data: TANCH) -> None;
    def remove(self: Memory, ids: (ID | Iterable[ID])) -> None;
    """Commit all data from memory to datasource."""
    def commit(self: Memory, anchor: (TANCH | None) = None) -> None { }

    def get_gc(self: Memory) -> <>list;
    def remove_from_gc(self: Memory, anchor: TANCH) -> None;
    def get_mem(self: Memory) -> <>dict;
    def remove_from_mem(self: Memory, anchor: (ID | UUID)) -> None;
}

"""Shelf Handler."""
@dataclass
class ShelfStorage(Memory[(UUID, Anchor)]) {
    with entry {
        __shelf__: (Shelf[Anchor] | None) = None;
    }

    def init(self: ShelfStorage, session: (str | None) = None) -> None;
    def commit(self: ShelfStorage, anchor: (Anchor | None) = None) -> None;
    def close(self: ShelfStorage) -> None;
    def sync_mem_to_db(self: ShelfStorage, keys: Iterable[UUID]) -> None;
    def query(
        self: ShelfStorage, filter: (Callable[([Anchor], bool)] | None) = None
    ) -> Generator[Any];

    def find(
        self: ShelfStorage,
        ids: (UUID | Iterable[UUID]),
        filter: (Callable[([Anchor], Anchor)] | None) = None
    ) -> Generator[Anchor];

    def find_by_id(self: ShelfStorage, id: UUID) -> (Anchor | None);
}
