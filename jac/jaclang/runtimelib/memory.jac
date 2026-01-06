"""Memory management for Jac Language."""

import from collections.abc { Callable, Generator, Iterable }
import from dataclasses { dataclass, field }
import from typing { Generic, TypeVar, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { TANCH, Root }

glob ID = TypeVar('ID'),
     __all__ = ['Memory'];

"""Generic Memory Handler.

Implements DataBackend protocol for L1 caching in the storage hierarchy.
Provides additional query and filtering capabilities beyond the base protocol.
"""
@dataclass
class Memory(Generic[ID, TANCH]) {
    has __mem__: dict[(ID | UUID), TANCH] = field(default_factory=dict),
        __gc__: set[TANCH] = field(default_factory=set);

    def is_available(self: Memory) -> bool;
    def get(self: Memory, id: ID) -> (TANCH | None);
    def put(self: Memory, data: TANCH) -> None;
    def delete(self: Memory, id: ID) -> None;
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

    def commit(self: Memory, anchor: (TANCH | None) = None) -> None;
    def get_gc(self: Memory) -> list[TANCH];
    def remove_from_gc(self: Memory, anchor: TANCH) -> None;
    def get_mem(self: Memory) -> dict[(ID | UUID), TANCH];
    def remove_from_mem(self: Memory, anchor: (ID | UUID)) -> None;
}

