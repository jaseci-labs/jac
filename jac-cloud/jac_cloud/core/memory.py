"""Memory abstraction for jaseci plugin."""

from dataclasses import dataclass
from os import getenv
from typing import (
    Callable,
    Generator,
    Iterable,
    TypeVar,
    Union,
    cast,
    overload,
)

from bson import ObjectId

from jaclang.runtimelib.machine import JacMachineInterface as Jac
from jaclang.runtimelib.memory import Memory


from pymongo import InsertOne
from pymongo.client_session import ClientSession

from .archetype import (
    BaseAnchor,
    BulkWrite,
    EdgeAnchor,
    NodeAnchor,
    NodeArchetype,
    ObjectAnchor,
    Root,
    ScheduleStatus,
    WalkerAnchor,
)
from ..jaseci.datasources import Collection

DISABLE_AUTO_CLEANUP = getenv("DISABLE_AUTO_CLEANUP") == "true"
SINGLE_QUERY = getenv("SINGLE_QUERY") == "true"
IDS = ObjectId | Iterable[ObjectId]
BA = TypeVar("BA", bound="BaseAnchor")


# mypy: disable-error-code="type-var"
@dataclass
class MongoDB(Memory[ObjectId, BaseAnchor]):
    """Shelf Handler."""

    __session__: ClientSession | None = None

    def populate_data(self, nodes: Iterable[NodeArchetype]) -> None:
        """Populate data to avoid multiple query."""
        if not SINGLE_QUERY:
            edges = (edge for node in nodes for edge in node.__jac__.edges)
            cnodes: set[NodeAnchor] = set()
            for edge in self.find(edges):
                if edge.source:
                    cnodes.add(edge.source)
                if edge.target:
                    cnodes.add(edge.target)
            self.find(cnodes)

    def find(  # type: ignore[override]
        self,
        anchors: BA | Iterable[BA],
        filter: Callable[[BaseAnchor], BaseAnchor] | None = None,
        session: ClientSession | None = None,
    ) -> Generator[BA, None, None]:
        """Find anchors from datasource by ids with filter."""
        if not isinstance(anchors, Iterable):
            anchors = [anchors]

        collections: dict[type[Collection[BaseAnchor]], list[ObjectId]] = {}
        for anchor in anchors:
            if anchor.id not in self.__mem__ and anchor not in self.__gc__:
                coll = collections.get(anchor.Collection)
                if coll is None:
                    coll = collections[anchor.Collection] = []

                coll.append(anchor.id)

        for cl, ids in collections.items():
            for anch_db in cl.find(
                {
                    "_id": {"$in": ids},
                },
                session=session or self.__session__,
            ):
                self.__mem__[anch_db.id] = anch_db  # type: ignore[assignment]

        for anchor in anchors:
            if (
                anchor not in self.__gc__
                and (anch_mem := self.__mem__.get(anchor.id))
                and (not filter or filter(anch_mem))
            ):
                yield cast(BA, anch_mem)

    def find_one(  # type: ignore[override]
        self,
        anchors: BA | Iterable[BA],
        filter: Callable[[BaseAnchor], BaseAnchor] | None = None,
        session: ClientSession | None = None,
    ) -> BA | None:
        """Find one anchor from memory by ids with filter."""
        return next(self.find(anchors, filter, session), None)

    @overload
    def find_by_id(self, id_or_anchor: BA) -> BA | None:  # type: ignore[override]
        ...

    @overload
    def find_by_id(self, id_or_anchor: ObjectId) -> BaseAnchor | None:  # type: ignore[override]
        ...

    def find_by_id(self, id_or_anchor: Union[ObjectId, BA]) -> Union[BaseAnchor, BA, None]:  # type: ignore[override]
        """Find one by id."""
        if isinstance(id_or_anchor, ObjectId):
            return super().find_by_id(id_or_anchor)  # type: ignore[arg-type]
        elif hasattr(id_or_anchor, "id"):
            data = super().find_by_id(id_or_anchor.id)  # type: ignore[arg-type]
            if (
                not data
                and hasattr(id_or_anchor, "Collection")
                and hasattr(id_or_anchor.Collection, "find_by_id")
            ):
                data_from_collection = id_or_anchor.Collection.find_by_id(
                    id_or_anchor.id
                )
                if data_from_collection:
                    self.__mem__[data_from_collection.id] = data_from_collection  # type: ignore[assignment]
                    return cast(BA, data_from_collection)
            return cast(BA, data)
        return None

    def commit(self, anchor: BaseAnchor | None = None) -> None:
        """Commit all data from memory to datasource."""
        if anchor:
            anchor.build_query(bulk_write := BulkWrite())
        else:
            bulk_write = self.get_bulk_write()

        if bulk_write.has_operations:
            if session := self.__session__:
                bulk_write.execute(session)
            else:
                with Collection.get_session() as session, session.start_transaction():
                    bulk_write.execute(session)

    def close(self) -> None:
        """Close memory handler."""
        self.commit()
        super().close()

    def sync_mem_to_db(self, bulk_write: BulkWrite, keys: Iterable[ObjectId]) -> None:
        """Manually sync memory to db."""
        for key in keys:
            anchor = self.__mem__.get(key)
            if (
                anchor
                and hasattr(anchor, "archetype")
                and anchor.archetype
                and hasattr(anchor, "persistent")
                and anchor.persistent
            ):
                if (
                    hasattr(anchor, "state")
                    and hasattr(anchor.state, "connected")
                    and not anchor.state.connected
                ):
                    anchor.state.connected = True
                    if hasattr(anchor, "sync_hash"):
                        anchor.sync_hash()  # type: ignore[operator]
                    if (
                        hasattr(anchor, "__class__")
                        and hasattr(bulk_write, "operations")
                        and isinstance(
                            anchor,
                            (NodeAnchor, EdgeAnchor, WalkerAnchor, ObjectAnchor),
                        )
                        and hasattr(anchor, "serialize")
                    ):
                        bulk_write.operations[anchor.__class__].append(  # type: ignore[index]
                            InsertOne(anchor.serialize())  # type: ignore[operator]
                        )
                        if (
                            isinstance(anchor, WalkerAnchor)
                            and hasattr(anchor, "schedule")
                            and anchor.schedule
                            and hasattr(anchor.schedule, "status")
                            and anchor.schedule.status == ScheduleStatus.PENDING
                        ):
                            bulk_write.schedules.append(anchor)
                elif (
                    hasattr(anchor, "has_changed")
                    and (new_hash := anchor.has_changed())  # type: ignore[operator]
                    and Jac.check_connect_access(anchor)  # type: ignore[arg-type]
                ):
                    if hasattr(anchor, "state") and hasattr(anchor.state, "full_hash"):
                        anchor.state.full_hash = new_hash
                    if (
                        not DISABLE_AUTO_CLEANUP
                        and isinstance(anchor, NodeAnchor)
                        and not isinstance(anchor.archetype, Root)
                        and hasattr(anchor, "edges")
                        and not anchor.edges
                    ):
                        bulk_write.del_node(anchor.id)
                    elif hasattr(anchor, "update"):
                        anchor.update(bulk_write)  # type: ignore[operator]

    def get_bulk_write(self) -> BulkWrite:
        """Sync memory to database."""
        bulk_write = BulkWrite()

        for anchor in self.__gc__:
            if isinstance(anchor, NodeAnchor):
                bulk_write.del_node(anchor.id)
            elif isinstance(anchor, EdgeAnchor):
                bulk_write.del_edge(anchor.id)
            elif isinstance(anchor, WalkerAnchor):
                bulk_write.del_walker(anchor.id)
            elif isinstance(anchor, ObjectAnchor):
                bulk_write.del_object(anchor.id)

        keys = set(self.__mem__.keys())

        # current memory
        self.sync_mem_to_db(bulk_write, keys)

        # additional after memory sync
        self.sync_mem_to_db(bulk_write, set(self.__mem__.keys() - keys))

        return bulk_write


__all__ = ["MongoDB"]
