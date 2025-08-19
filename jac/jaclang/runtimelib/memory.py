"""Core constructs for Jac Language."""

from __future__ import annotations

from dataclasses import dataclass, field
from pickle import dumps
from shelve import Shelf, open
from typing import Any, Callable, Generator, Generic, Iterable, TypeVar, cast
from uuid import UUID

from .archetype import Anchor, NodeAnchor, Root, TANCH

ID = TypeVar("ID")


@dataclass
class Memory(Generic[ID, TANCH]):
    """Generic Memory Handler."""

    __mem__: dict[ID, TANCH] = field(default_factory=dict)
    __gc__: set[TANCH] = field(default_factory=set)

    def close(self) -> None:
        """Close memory handler."""
        self.__mem__.clear()
        self.__gc__.clear()

    def is_cached(self, id: ID) -> bool:
        """Check if id if already cached."""
        return id in self.__mem__

    def query(
        self, filter: Callable[[TANCH], bool] | None = None
    ) -> Generator[TANCH, None, None]:
        """Find anchors from memory with filter."""
        return (
            anchor for anchor in self.__mem__.values() if not filter or filter(anchor)
        )

    def all_root(self) -> Generator[Root, None, None]:
        """Get all the roots."""
        for anchor in self.query(lambda anchor: isinstance(anchor.archetype, Root)):
            yield cast(Root, anchor.archetype)

    def find(
        self,
        ids: ID | Iterable[ID],
        filter: Callable[[TANCH], TANCH] | None = None,
    ) -> Generator[TANCH, None, None]:
        """Find anchors from memory by ids with filter."""
        if not isinstance(ids, Iterable):
            ids = [ids]

        return (
            anchor
            for id in ids
            if (anchor := self.__mem__.get(id)) and (not filter or filter(anchor))
        )

    def find_one(
        self,
        ids: ID | Iterable[ID],
        filter: Callable[[TANCH], TANCH] | None = None,
    ) -> TANCH | None:
        """Find one anchor from memory by ids with filter."""
        return next(self.find(ids, filter), None)

    def find_by_id(self, id: ID) -> TANCH | None:
        """Find one by id."""
        return self.__mem__.get(id)

    def set(self, id: ID, data: TANCH) -> None:
        """Save anchor to memory."""
        self.__mem__[id] = data

    def remove(self, ids: ID | Iterable[ID]) -> None:
        """Remove anchor/s from memory."""
        if not isinstance(ids, Iterable):
            ids = [ids]

        for id in ids:
            if anchor := self.__mem__.pop(id, None):
                self.__gc__.add(anchor)

    def commit(self, anchor: TANCH | None = None) -> None:
        """Commit all data from memory to datasource."""


@dataclass
class ShelfStorage(Memory[UUID, Anchor]):
    """Shelf Handler."""

    __shelf__: Shelf[Anchor] | None = None

    def __init__(self, session: str | None = None) -> None:
        """Initialize memory handler."""
        super().__init__()
        self.__shelf__ = open(session) if session else None  # noqa: SIM115

    def commit(self, anchor: Anchor | None = None) -> None:
        """Commit all data from memory to datasource."""
        if isinstance(self.__shelf__, Shelf):
            if anchor:
                if anchor in self.__gc__:
                    self.__shelf__.pop(str(anchor.id), None)
                    self.__mem__.pop(anchor.id, None)
                    self.__gc__.remove(anchor)
                else:
                    self.sync_mem_to_db([anchor.id])
                return

            for anc in self.__gc__:
                self.__shelf__.pop(str(anc.id), None)
                self.__mem__.pop(anc.id, None)

            keys = set(self.__mem__.keys())

            # current memory
            self.sync_mem_to_db(keys)

            # additional after memory sync
            self.sync_mem_to_db(set(self.__mem__.keys() - keys))

    def close(self) -> None:
        """Close memory handler."""
        self.commit()

        if isinstance(self.__shelf__, Shelf):
            self.__shelf__.close()

        super().close()

    def sync_mem_to_db(self, keys: Iterable[UUID]) -> None:
        """Manually sync memory to db."""
        from jaclang.runtimelib.machine import JacMachineInterface as Jac

        if isinstance(self.__shelf__, Shelf):
            for key in keys:
                if (
                    (d := self.__mem__.get(key))
                    and d.persistent
                    and d.hash != hash(dumps(d))
                ):
                    _id = str(d.id)
                    if p_d := self.__shelf__.get(_id):
                        if (
                            isinstance(p_d, NodeAnchor)
                            and isinstance(d, NodeAnchor)
                            and p_d.edges != d.edges
                            and Jac.check_connect_access(d)
                        ):
                            if not d.edges and not isinstance(d.archetype, Root):
                                self.__shelf__.pop(_id, None)
                                continue
                            p_d.edges = d.edges

                        if Jac.check_write_access(d):
                            if hash(dumps(p_d.access)) != hash(dumps(d.access)):
                                p_d.access = d.access
                            if hash(dumps(p_d.archetype)) != hash(dumps(d.archetype)):
                                p_d.archetype = d.archetype

                        self.__shelf__[_id] = p_d
                    elif not (
                        isinstance(d, NodeAnchor)
                        and not isinstance(d.archetype, Root)
                        and not d.edges
                    ):
                        self.__shelf__[_id] = d

    def query(
        self, filter: Callable[[Anchor], bool] | None = None
    ) -> Generator[Any, None, None]:
        """Find anchors from memory with filter."""
        if isinstance(self.__shelf__, Shelf):
            for anchor in self.__shelf__.values():
                if not filter or filter(anchor):
                    if anchor.id not in self.__mem__:
                        self.__mem__[anchor.id] = anchor
                    yield anchor
        else:
            yield from super().query(filter)

    def find(
        self,
        ids: UUID | Iterable[UUID],
        filter: Callable[[Anchor], Anchor] | None = None,
    ) -> Generator[Anchor, None, None]:
        """Find anchors from datasource by ids with filter."""
        if not isinstance(ids, Iterable):
            ids = [ids]

        if isinstance(self.__shelf__, Shelf):
            for id in ids:
                anchor = self.__mem__.get(id)

                if (
                    not anchor
                    and id not in self.__gc__
                    and (_anchor := self.__shelf__.get(str(id)))
                ):
                    self.__mem__[id] = anchor = _anchor
                if anchor and (not filter or filter(anchor)):
                    yield anchor
        else:
            yield from super().find(ids, filter)

    def find_by_id(self, id: UUID) -> Anchor | None:
        """Find one by id."""
        data = super().find_by_id(id)

        if (
            not data
            and isinstance(self.__shelf__, Shelf)
            and (data := self.__shelf__.get(str(id)))
        ):
            self.__mem__[id] = data

        return data
