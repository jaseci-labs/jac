"""Core constructs for Jac Language."""

from dataclasses import (
    MISSING,
    asdict as _asdict,
    dataclass,
    field,
    fields,
    is_dataclass,
)
from datetime import datetime
from enum import Enum, StrEnum
from functools import cached_property
from itertools import islice
from os import getenv
from pickle import dumps as pdumps
from re import IGNORECASE, compile
from types import GenericAlias, UnionType
from typing import (
    Any,
    ClassVar,
    Iterable,
    Mapping,
    TypeVar,
    cast,
    get_args,
    get_origin,
    get_type_hints,
)

from bson import ObjectId

from jaclang.runtimelib.archetype import (
    Access as _Access,
    AccessLevel,
    Anchor,
    EdgeAnchor as _EdgeAnchor,
    EdgeArchetype as _EdgeArchetype,
    NodeAnchor as _NodeAnchor,
    NodeArchetype as _NodeArchetype,
    ObjectAnchor as _ObjectAnchor,
    ObjectArchetype as _ObjectArchetype,
    Permission as _Permission,
    TANCH,
    WalkerAnchor as _WalkerAnchor,
    WalkerArchetype as _WalkerArchetype,
)
from jaclang.runtimelib.machine import JacMachineInterface as Jac
from jaclang.runtimelib.utils import is_instance

from orjson import dumps

from pymongo import ASCENDING, DeleteMany, DeleteOne, InsertOne, UpdateMany, UpdateOne
from pymongo.client_session import ClientSession
from pymongo.errors import ConnectionFailure, OperationFailure

from ..jaseci.datasources import (
    Collection as BaseCollection,
    ScheduleRedis,
)
from ..jaseci.utils import logger

MANUAL_SAVE = getenv("MANUAL_SAVE")
GENERIC_ID_REGEX = compile(r"^(n|e|w|o):([^:]*):([a-f\d]{24})$", IGNORECASE)
NODE_ID_REGEX = compile(r"^n:([^:]*):([a-f\d]{24})$", IGNORECASE)
EDGE_ID_REGEX = compile(r"^e:([^:]*):([a-f\d]{24})$", IGNORECASE)
WALKER_ID_REGEX = compile(r"^w:([^:]*):([a-f\d]{24})$", IGNORECASE)
OBJECT_ID_REGEX = compile(r"^o:([^:]*):([a-f\d]{24})$", IGNORECASE)
T = TypeVar("T")
TBA = TypeVar("TBA", bound="BaseArchetype")


def asdict_factory(data: Iterable[tuple]) -> dict[str, Any]:
    """Parse dataclass to dict."""
    _data = {}
    for key, value in data:
        if isinstance(value, Enum):
            _data[key] = value.name
        else:
            _data[key] = value
    return _data


def asdict(obj: object) -> dict[str, Any]:
    """Override dataclass asdict."""
    if is_dataclass(obj) and not isinstance(obj, type):
        return _asdict(obj, dict_factory=asdict_factory)
    raise ValueError("Object is not a dataclass!")


def archetype_to_dataclass(cls: type[T], data: dict[str, Any], **kwargs: object) -> T:
    """Parse dict to archetype."""
    _to_dataclass(cls, data)
    archetype = object.__new__(cls)
    hintings = get_type_hints(cls)
    if is_dataclass(cls):
        for attr in fields(cls):
            if (val := data.pop(attr.name, MISSING)) is MISSING:
                if attr.default is not MISSING:
                    setattr(archetype, attr.name, attr.default)
                elif attr.default_factory is not MISSING and callable(
                    attr.default_factory
                ):
                    setattr(archetype, attr.name, attr.default_factory())
                else:
                    raise ValueError(
                        f"{cls.__name__} requires {attr.name} field with type {hintings[attr.name]}"
                    )
            else:
                hinter = hintings[attr.name]
                origin = get_origin(hinter)
                if hinter == Any:
                    setattr(archetype, attr.name, val)
                    continue
                elif origin == UnionType or origin is None:
                    if is_instance(val, hinter):
                        setattr(archetype, attr.name, val)
                        continue
                elif origin and is_instance(val, origin):
                    setattr(archetype, attr.name, val)
                    continue
                raise ValueError(
                    f"Data from datasource has type {val.__class__.__name__}"
                    f" but {cls.__name__}.{attr.name} requires {hinter}."
                )

    archetype.__dict__.update(data)
    archetype.__dict__.update(kwargs)
    return archetype


def to_dataclass(cls: type[T], data: dict[str, Any], **kwargs: object) -> T:
    """Parse dict to dataclass."""
    _to_dataclass(cls, data)
    return cls(**data, **kwargs)


def _to_dataclass(cls: type[T], data: dict[str, Any]) -> None:
    """Parse dict to dataclass implementation."""
    hintings = get_type_hints(cls)
    if is_dataclass(cls):
        for attr in fields(cls):
            if target := data.get(attr.name):
                hint = hintings[attr.name]
                if is_dataclass(hint) and isinstance(hint, type):
                    data[attr.name] = to_dataclass(hint, target)
                else:
                    origin = get_origin(hint)
                    if origin == dict and isinstance(target, dict):
                        if is_dataclass(inner_cls := get_args(hint)[-1]) and isinstance(
                            inner_cls, type
                        ):
                            for key, value in target.items():
                                target[key] = to_dataclass(inner_cls, value)
                    elif (
                        origin == list
                        and isinstance(target, list)
                        and is_dataclass(inner_cls := get_args(hint)[-1])
                        and isinstance(inner_cls, type)
                    ):
                        for key, value in enumerate(target):
                            target[key] = to_dataclass(inner_cls, value)
                    elif (
                        origin != UnionType
                        and not isinstance(hint, GenericAlias)
                        and issubclass(hint, Enum)
                        and isinstance(target, str)
                        and (enum := hint.__members__.get(target))
                    ):
                        data[attr.name] = enum


class ScheduleStatus(StrEnum):
    """Schedule Status."""

    PENDING = "PENDING"
    STARTED = "STARTED"
    COMPLETED = "COMPLETED"
    ERROR = "ERROR"


@dataclass(eq=False)
class Schedule:
    """Schedule."""

    status: ScheduleStatus = ScheduleStatus.PENDING
    node_id: str | None = None
    root_id: str | None = None
    execute_date: datetime | None = None
    executed_date: datetime | None = None
    http_status: int | None = None
    reports: list[Any] | None = None
    custom: Any = None
    error: list[str] | None = None


@dataclass
class BulkWrite:
    """Bulk Write builder."""

    SESSION_MAX_TRANSACTION_RETRY: ClassVar[int] = int(
        getenv("SESSION_MAX_TRANSACTION_RETRY") or "1"
    )
    SESSION_MAX_COMMIT_RETRY: ClassVar[int] = int(
        getenv("SESSION_MAX_COMMIT_RETRY") or "1"
    )

    operations: dict[
        type["BaseAnchor"],
        list[InsertOne[Any] | DeleteMany | DeleteOne | UpdateMany | UpdateOne],
    ] = field(
        default_factory=lambda: {
            NodeAnchor: [],
            EdgeAnchor: [],
            WalkerAnchor: [],
            ObjectAnchor: [],
        }
    )
    schedules: list["WalkerAnchor"] = field(default_factory=list)

    del_ops_nodes: list[ObjectId] = field(default_factory=list)
    del_ops_edges: list[ObjectId] = field(default_factory=list)
    del_ops_walker: list[ObjectId] = field(default_factory=list)
    del_ops_object: list[ObjectId] = field(default_factory=list)

    def del_node(self, id: ObjectId) -> None:
        """Add node to delete many operations."""
        if not self.del_ops_nodes:
            self.operations[NodeAnchor].append(
                DeleteMany({"_id": {"$in": self.del_ops_nodes}})
            )

        self.del_ops_nodes.append(id)

    def del_edge(self, id: ObjectId) -> None:
        """Add edge to delete many operations."""
        if not self.del_ops_edges:
            self.operations[EdgeAnchor].append(
                DeleteMany({"_id": {"$in": self.del_ops_edges}})
            )

        self.del_ops_edges.append(id)

    def del_walker(self, id: ObjectId) -> None:
        """Add walker to delete many operations."""
        if not self.del_ops_walker:
            self.operations[WalkerAnchor].append(
                DeleteMany({"_id": {"$in": self.del_ops_walker}})
            )

        self.del_ops_walker.append(id)

    def del_object(self, id: ObjectId) -> None:
        """Add walker to delete many operations."""
        if not self.del_ops_object:
            self.operations[ObjectAnchor].append(
                DeleteMany({"_id": {"$in": self.del_ops_object}})
            )

        self.del_ops_object.append(id)

    @property
    def has_operations(self) -> bool:
        """Check if has operations."""
        return any(val for val in self.operations.values())

    @staticmethod
    def commit(session: ClientSession) -> None:
        """Commit current session."""
        commit_retry = 0
        while True:
            try:
                session.commit_transaction()
                break
            except (ConnectionFailure, OperationFailure) as ex:
                if (
                    ex.has_error_label("UnknownTransactionCommitResult")
                    and commit_retry <= BulkWrite.SESSION_MAX_COMMIT_RETRY
                ):
                    commit_retry += 1
                    logger.exception(
                        "Error commiting session! "
                        f"Retrying [{commit_retry}/{BulkWrite.SESSION_MAX_COMMIT_RETRY}] ..."
                    )
                    continue
                logger.exception(
                    f"Error commiting session after max retry [{BulkWrite.SESSION_MAX_COMMIT_RETRY}] !"
                )
                raise
            except Exception:
                logger.exception("Error commiting session!")
                raise

    def execute(self, session: ClientSession) -> None:
        """Execute all operations."""
        transaction_retry = 0
        while True:
            try:
                if node_operation := self.operations[NodeAnchor]:
                    NodeAnchor.Collection.bulk_write(node_operation, False, session)
                if edge_operation := self.operations[EdgeAnchor]:
                    EdgeAnchor.Collection.bulk_write(edge_operation, False, session)
                if walker_operation := self.operations[WalkerAnchor]:
                    WalkerAnchor.Collection.bulk_write(walker_operation, False, session)
                if object_operation := self.operations[ObjectAnchor]:
                    ObjectAnchor.Collection.bulk_write(object_operation, False, session)
                self.commit(session)

                if self.schedules:
                    ScheduleRedis.rpush(
                        "scheduled",
                        *(
                            {
                                "walker_id": w.ref_id,
                                "execute_date": w.schedule.execute_date,
                                "node_id": w.schedule.node_id,
                                "root_id": f"n::{w.root}",
                            }
                            for w in self.schedules
                            if w.schedule
                        ),
                    )
                break
            except (ConnectionFailure, OperationFailure) as ex:
                if (
                    ex.has_error_label("TransientTransactionError")
                    and transaction_retry <= self.SESSION_MAX_TRANSACTION_RETRY
                ):
                    transaction_retry += 1
                    logger.exception(
                        "Error executing bulk write! "
                        f"Retrying [{transaction_retry}/{self.SESSION_MAX_TRANSACTION_RETRY}] ..."
                    )
                    continue
                logger.exception(
                    f"Error executing bulk write after max retry [{self.SESSION_MAX_TRANSACTION_RETRY}] !"
                )
                raise
            except Exception:
                logger.exception("Error executing bulk write!")
                raise


@dataclass
class Access(_Access):
    """Access Structure."""

    def serialize(self) -> dict[str, object]:
        """Serialize Access."""
        return {
            "anchors": {key: val.name for key, val in self.anchors.items()},
        }

    @classmethod
    def deserialize(cls, data: dict[str, Any]) -> "Access":
        """Deserialize Access."""
        anchors = cast(dict[str, str], data.get("anchors"))
        return Access(
            anchors={key: AccessLevel[val] for key, val in anchors.items()},
        )


@dataclass
class Permission(_Permission):
    """Anchor Access Handler."""

    roots: Access = field(default_factory=Access)

    def serialize(self) -> dict[str, object]:
        """Serialize Permission."""
        return {"all": self.all.name, "roots": self.roots.serialize()}

    @classmethod
    def deserialize(cls, data: dict[str, Any]) -> "Permission":
        """Deserialize Permission."""
        return Permission(
            all=AccessLevel[data.get("all", AccessLevel.NO_ACCESS.name)],
            roots=Access.deserialize(data.get("roots", {})),
        )


@dataclass
class AnchorState:
    """Anchor state handler."""

    changes: dict[str, dict[str, Any]] = field(default_factory=dict)
    full_hash: int = 0
    context_hashes: dict[str, int] = field(default_factory=dict)
    deleted: bool | None = None
    connected: bool = False


@dataclass
class WalkerAnchorState(AnchorState):
    """Anchor state handler."""

    schedule_hashes: dict[str, int] = field(default_factory=dict)


@dataclass(eq=False, repr=False, kw_only=True)
class BaseAnchor:
    """Base Anchor."""

    archetype: "BaseArchetype"
    name: str = ""
    id: ObjectId = field(default_factory=ObjectId)
    root: ObjectId | None = None
    access: Permission
    state: AnchorState

    class Collection(BaseCollection["BaseAnchor"]):
        """Anchor collection interface."""

        pass

    @property
    def ref_id(self) -> str:
        """Return id in reference type."""
        return f"{self.__class__.__name__[:1].lower()}:{self.name}:{self.id}"

    @staticmethod
    def ref(ref_id: str) -> "BaseAnchor | Anchor":
        """Return ObjectAnchor instance if ."""
        if match := GENERIC_ID_REGEX.search(ref_id):
            cls: type[BaseAnchor]

            match match.group(1):
                case "n":
                    cls = NodeAnchor
                case "e":
                    cls = EdgeAnchor
                case "w":
                    cls = WalkerAnchor
                case "o":
                    cls = ObjectAnchor
                case _:
                    raise ValueError(f"[{ref_id}] is not a valid reference!")
            anchor = object.__new__(cls)
            anchor.name = str(match.group(2))
            anchor.id = ObjectId(match.group(3))
            return anchor
        raise ValueError(f"[{ref_id}] is not a valid reference!")

    ####################################################
    #                 QUERY OPERATIONS                 #
    ####################################################

    @property
    def _set(self) -> dict:
        if "$set" not in self.state.changes:
            self.state.changes["$set"] = {}
        return self.state.changes["$set"]

    @property
    def _unset(self) -> dict:
        if "$unset" not in self.state.changes:
            self.state.changes["$unset"] = {}
        return self.state.changes["$unset"]

    @property
    def _add_to_set(self) -> dict:
        if "$addToSet" not in self.state.changes:
            self.state.changes["$addToSet"] = {}

        return self.state.changes["$addToSet"]

    @property
    def _pull(self) -> dict:
        if "$pull" not in self.state.changes:
            self.state.changes["$pull"] = {}

        return self.state.changes["$pull"]

    def add_to_set(self, field: str, anchor: Anchor, remove: bool = False) -> None:
        """Add to set."""
        if field not in (add_to_set := self._add_to_set):
            add_to_set[field] = {"$each": []}

        ops: list = add_to_set[field]["$each"]

        if remove:
            if anchor in ops:
                ops.remove(anchor)
        else:
            ops.append(anchor)
            self.pull(field, anchor, True)

    def pull(self, field: str, anchor: Anchor, remove: bool = False) -> None:
        """Pull from set."""
        if field not in (pull := self._pull):
            pull[field] = {"$in": set()}

        ops: set = pull[field]["$in"]

        if remove:
            if anchor in ops:
                ops.remove(anchor)
        else:
            ops.add(anchor)
            self.add_to_set(field, anchor, True)

    def connect_edge(self, anchor: Anchor) -> None:
        """Push update that there's newly added edge."""
        self.add_to_set("edges", anchor)

    def disconnect_edge(self, anchor: Anchor) -> None:
        """Push update that there's edge that has been removed."""
        self.pull("edges", anchor)

    ####################################################
    #                POPULATE OPERATIONS               #
    ####################################################

    def is_populated(self) -> bool:
        """Check if populated."""
        return "archetype" in self.__dict__

    def make_stub(self: "BaseAnchor | TANCH") -> "BaseAnchor | TANCH":
        """Return unsynced copy of anchor."""
        if self.is_populated():
            unloaded = object.__new__(self.__class__)
            # this will be refactored on abstraction
            unloaded.name = self.name  # type: ignore[union-attr]
            unloaded.id = self.id  # type: ignore[attr-defined]
            return unloaded  # type: ignore[return-value]
        return self

    def populate(self) -> None:
        """Retrieve the Archetype from db and return."""
        from .context import JaseciContext

        jsrc = JaseciContext.get().mem

        if anchor := jsrc.find_by_id(self):
            self.__dict__.update(anchor.__dict__)
        else:
            raise ValueError(
                f"{self.__class__.__name__} [{self.ref_id}] is not a valid reference!"
            )

    def build_query(
        self,
        bulk_write: BulkWrite,
    ) -> None:
        """Save Anchor."""
        if self.state.deleted is False and Jac.check_write_access(self):  # type: ignore[arg-type]
            self.state.deleted = True
            self.delete(bulk_write)
        elif not self.state.connected:
            self.state.connected = True
            self.sync_hash()
            self.insert(bulk_write)
        elif Jac.check_connect_access(self):  # type: ignore[arg-type]
            self.update(bulk_write, True)

    def insert(
        self,
        bulk_write: BulkWrite,
    ) -> None:
        """Append Insert Query."""
        raise NotImplementedError("insert must be implemented in subclasses")

    def update(self, bulk_write: BulkWrite, propagate: bool = False) -> None:
        """Append Update Query."""
        changes = self.state.changes
        self.state.changes = {}  # renew reference

        operations = bulk_write.operations[self.__class__]
        operation_filter = {"_id": self.id}

        ############################################################
        #                     POPULATE CONTEXT                     #
        ############################################################

        if Jac.check_write_access(self):  # type: ignore[arg-type]
            set_query = changes.pop("$set", {})
            if is_dataclass(archetype := self.archetype) and not isinstance(
                archetype, type
            ):
                for (
                    key,
                    val,
                ) in (
                    archetype.__serialize__().items()  # type:ignore[attr-defined] # mypy issue
                ):
                    if (h := hash(dumps(val))) != self.state.context_hashes.get(key):
                        self.state.context_hashes[key] = h
                        set_query[f"archetype.{key}"] = val
            if set_query:
                changes["$set"] = set_query
        else:
            changes.pop("$set", None)
            changes.pop("$unset", None)

        # -------------------------------------------------------- #
        match self:
            case WalkerAnchor():
                if is_dataclass(schedule := self.schedule) and not isinstance(
                    schedule, type
                ):
                    for key, val in asdict(schedule).items():
                        if (h := hash(dumps(val))) != self.state.schedule_hashes.get(
                            key
                        ):
                            self.state.schedule_hashes[key] = h
                            set_query[f"schedule.{key}"] = val

                if self.schedule and self.schedule.status == ScheduleStatus.PENDING:
                    bulk_write.schedules.append(self)
            case NodeAnchor():
                ############################################################
                #                   POPULATE ADDED EDGES                   #
                ############################################################
                added_edges: set[BaseAnchor] = (
                    changes.get("$addToSet", {}).get("edges", {}).get("$each", [])
                )
                if added_edges:
                    _added_edges = []
                    for anchor in added_edges:
                        if propagate:
                            anchor.build_query(bulk_write)  # type: ignore[operator]
                        _added_edges.append(anchor.ref_id)
                    changes["$addToSet"]["edges"]["$each"] = _added_edges
                else:
                    changes.pop("$addToSet", None)

                # -------------------------------------------------------- #

                ############################################################
                #                  POPULATE REMOVED EDGES                  #
                ############################################################
                pulled_edges: set[BaseAnchor] = (
                    changes.get("$pull", {}).get("edges", {}).get("$in", [])
                )
                if pulled_edges:
                    _pulled_edges = []
                    for anchor in pulled_edges:
                        # will be refactored on abstraction
                        if propagate and anchor.state.deleted is not True:  # type: ignore[attr-defined]
                            anchor.state.deleted = True  # type: ignore[attr-defined]
                            bulk_write.del_edge(anchor.id)  # type: ignore[attr-defined, arg-type]
                        _pulled_edges.append(anchor.ref_id)

                    if added_edges:
                        # Isolate pull to avoid conflict with addToSet
                        changes.pop("$pull", None)
                        operations.append(
                            UpdateOne(
                                operation_filter,
                                {"$pull": {"edges": {"$in": _pulled_edges}}},
                            )
                        )
                    else:
                        changes["$pull"]["edges"]["$in"] = _pulled_edges
                else:
                    changes.pop("$pull", None)

                # -------------------------------------------------------- #
            case _:
                pass

        if changes:
            operations.append(UpdateOne(operation_filter, changes))

    def delete(self, bulk_write: BulkWrite) -> None:
        """Append Delete Query."""
        raise NotImplementedError("delete must be implemented in subclasses")

    def has_changed(self) -> int:
        """Check if needs to update."""
        if self.state.full_hash != (new_hash := hash(pdumps(self.serialize()))):
            return new_hash
        return 0

    def sync_hash(self) -> None:
        """Sync current serialization hash."""
        if is_dataclass(archetype := self.archetype) and not isinstance(
            archetype, type
        ):
            self.state.context_hashes = {
                key: hash(val if isinstance(val, bytes) else dumps(val))
                for key, val in archetype.__serialize__().items()  # type:ignore[attr-defined] # mypy issue
            }
        self.state.full_hash = hash(pdumps(self.serialize()))

    # ---------------------------------------------------------------------- #

    def report(self) -> dict[str, object]:
        """Report Anchor."""
        return {
            "id": self.ref_id,
            "context": (
                self.archetype.__serialize__()  # type:ignore[attr-defined] # mypy issue
                if is_dataclass(self.archetype) and not isinstance(self.archetype, type)
                else {}
            ),
        }

    def serialize(self) -> dict[str, object]:
        """Serialize Anchor."""
        return {
            "_id": self.id,
            "name": self.name,
            "root": self.root,
            "access": self.access.serialize(),
            "archetype": (
                self.archetype.__serialize__()  # type:ignore[attr-defined] # mypy issue
                if is_dataclass(self.archetype) and not isinstance(self.archetype, type)
                else {}
            ),
        }

    def __repr__(self) -> str:
        """Override representation."""
        if self.is_populated():
            attrs = ""
            for f in fields(self):
                if f.name in self.__dict__:
                    attrs += f"{f.name}={self.__dict__[f.name]}, "
            attrs = attrs[:-2]
        else:
            attrs = f"name={self.name}, id={self.id}"

        return f"{self.__class__.__name__}({attrs})"


@dataclass(eq=False, repr=False, kw_only=True)
class NodeAnchor(BaseAnchor, _NodeAnchor):  # type: ignore[misc]
    """Node Anchor."""

    archetype: "NodeArchetype"
    edges: list["EdgeAnchor"]  # type: ignore[assignment]

    class Collection(BaseCollection["NodeAnchor"]):
        """NodeAnchor collection interface."""

        __collection__: str | None = "node"
        __default_indexes__: list[dict] = [
            {"keys": [("_id", ASCENDING), ("name", ASCENDING), ("root", ASCENDING)]}
        ]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "NodeAnchor":
            """Parse document to NodeAnchor."""
            doc = cast(dict, doc)

            archetype = archetype_to_dataclass(
                NodeArchetype.__get_class__(doc.get("name") or ""),
                doc.pop("archetype"),
            )
            anchor = NodeAnchor(
                archetype=archetype,
                id=doc.pop("_id"),
                edges=[e for edge in doc.pop("edges") if (e := EdgeAnchor.ref(edge))],
                access=Permission.deserialize(doc.pop("access")),
                state=AnchorState(connected=True),
                persistent=True,
                **doc,
            )
            archetype.__jac__ = anchor
            anchor.sync_hash()
            return anchor

    @classmethod
    def ref(cls, ref_id: str) -> "NodeAnchor":
        """Return NodeAnchor instance if existing."""
        if match := NODE_ID_REGEX.search(ref_id):
            anchor = object.__new__(cls)
            anchor.name = str(match.group(1))
            anchor.id = ObjectId(match.group(2))
            return anchor
        raise ValueError(f"[{ref_id}] is not a valid reference!")

    def insert(
        self,
        bulk_write: BulkWrite,
    ) -> None:
        """Append Insert Query."""
        for edge in self.edges:
            edge.build_query(bulk_write)

        bulk_write.operations[NodeAnchor].append(InsertOne(self.serialize()))

    def delete(self, bulk_write: BulkWrite) -> None:
        """Append Delete Query."""
        for edge in self.edges:
            edge.delete(bulk_write)

        pulled_edges: set[EdgeAnchor] = self._pull.get("edges", {}).get("$in", [])
        for edge in pulled_edges:
            edge.delete(bulk_write)

        bulk_write.del_node(self.id)

    def serialize(self) -> dict[str, object]:
        """Serialize Node Anchor."""
        return {
            **super().serialize(),
            "edges": [edge.ref_id for edge in self.edges],
        }


@dataclass(eq=False, repr=False, kw_only=True)
class EdgeAnchor(BaseAnchor, _EdgeAnchor):  # type: ignore[misc]
    """Edge Anchor."""

    archetype: "EdgeArchetype"
    source: NodeAnchor
    target: NodeAnchor
    is_undirected: bool

    class Collection(BaseCollection["EdgeAnchor"]):
        """EdgeAnchor collection interface."""

        __collection__: str | None = "edge"
        __default_indexes__: list[dict] = [
            {"keys": [("_id", ASCENDING), ("name", ASCENDING), ("root", ASCENDING)]}
        ]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "EdgeAnchor":
            """Parse document to EdgeAnchor."""
            doc = cast(dict, doc)
            archetype = archetype_to_dataclass(
                EdgeArchetype.__get_class__(doc.get("name") or ""),
                doc.pop("archetype"),
            )
            anchor = EdgeAnchor(
                archetype=archetype,
                id=doc.pop("_id"),
                source=NodeAnchor.ref(doc.pop("source")),
                target=NodeAnchor.ref(doc.pop("target")),
                access=Permission.deserialize(doc.pop("access")),
                state=AnchorState(connected=True),
                persistent=True,
                **doc,
            )
            archetype.__jac__ = anchor
            anchor.sync_hash()
            return anchor

    @classmethod
    def ref(cls, ref_id: str) -> "EdgeAnchor":
        """Return EdgeAnchor instance if existing."""
        if match := EDGE_ID_REGEX.search(ref_id):
            anchor = object.__new__(cls)
            anchor.name = str(match.group(1))
            anchor.id = ObjectId(match.group(2))
            return anchor
        raise ValueError(f"{ref_id}] is not a valid reference!")

    def insert(self, bulk_write: BulkWrite) -> None:
        """Append Insert Query."""
        if source := self.source:
            source.build_query(bulk_write)

        if target := self.target:
            target.build_query(bulk_write)

        bulk_write.operations[EdgeAnchor].append(InsertOne(self.serialize()))

    def delete(self, bulk_write: BulkWrite) -> None:
        """Append Delete Query."""
        if source := self.source:
            source.build_query(bulk_write)

        if target := self.target:
            target.build_query(bulk_write)

        bulk_write.del_edge(self.id)

    def serialize(self) -> dict[str, object]:
        """Serialize Node Anchor."""
        return {
            **super().serialize(),
            "source": self.source.ref_id if self.source else None,
            "target": self.target.ref_id if self.target else None,
            "is_undirected": self.is_undirected,
        }


@dataclass(eq=False, repr=False, kw_only=True)
class WalkerAnchor(BaseAnchor, _WalkerAnchor):  # type: ignore[misc]
    """Walker Anchor."""

    archetype: "WalkerArchetype"
    state: WalkerAnchorState
    path: list[NodeAnchor | EdgeAnchor] = field(default_factory=list)  # type: ignore[assignment]
    next: list[NodeAnchor | EdgeAnchor] = field(default_factory=list)  # type: ignore[assignment]
    ignores: list[NodeAnchor] = field(default_factory=list)  # type: ignore[assignment]
    disengaged: bool = False
    schedule: Schedule | None = None

    class Collection(BaseCollection["WalkerAnchor"]):
        """WalkerAnchor collection interface."""

        __collection__: str | None = "walker"
        __default_indexes__: list[dict] = [
            {"keys": [("_id", ASCENDING), ("name", ASCENDING), ("root", ASCENDING)]},
            {
                "keys": [
                    ("_id", ASCENDING),
                    ("name", ASCENDING),
                    ("root", ASCENDING),
                    ("schedule.status", ASCENDING),
                ]
            },
        ]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "WalkerAnchor":
            """Parse document to WalkerAnchor."""
            doc = cast(dict, doc)
            archetype = archetype_to_dataclass(
                WalkerArchetype.__get_class__(doc.get("name") or ""),
                doc.pop("archetype"),
            )

            if next := doc.pop("next", []):
                next = [NodeAnchor.ref(n) for n in next]

            if schedule := doc.pop("schedule"):
                schedule = Schedule(ScheduleStatus(schedule.pop("status")), **schedule)

            anchor = WalkerAnchor(
                archetype=archetype,
                id=doc.pop("_id"),
                access=Permission.deserialize(doc.pop("access")),
                state=WalkerAnchorState(connected=True),
                persistent=True,
                next=next,
                schedule=schedule,
                **doc,
            )
            archetype.__jac__ = anchor
            anchor.sync_hash()
            return anchor

    @classmethod
    def ref(cls, ref_id: str) -> "WalkerAnchor":
        """Return EdgeAnchor instance if existing."""
        if match := WALKER_ID_REGEX.search(ref_id):
            anchor = object.__new__(cls)
            anchor.name = str(match.group(1))
            anchor.id = ObjectId(match.group(2))
            return anchor
        raise ValueError(f"{ref_id}] is not a valid reference!")

    def insert(
        self,
        bulk_write: BulkWrite,
    ) -> None:
        """Append Insert Query."""
        bulk_write.operations[WalkerAnchor].append(InsertOne(self.serialize()))

        if self.schedule and self.schedule.status == ScheduleStatus.PENDING:
            bulk_write.schedules.append(self)

    def delete(self, bulk_write: BulkWrite) -> None:
        """Append Delete Query."""
        bulk_write.del_walker(self.id)

    def sync_hash(self) -> None:
        """Sync current serialization hash."""
        if is_dataclass(archetype := self.archetype) and not isinstance(
            archetype, type
        ):
            self.state.context_hashes = {
                key: hash(val if isinstance(val, bytes) else dumps(val))
                for key, val in archetype.__serialize__().items()
            }

        if is_dataclass(schedule := self.schedule) and not isinstance(schedule, type):
            self.state.schedule_hashes = {
                key: hash(val if isinstance(val, bytes) else dumps(val))
                for key, val in asdict(schedule).items()
            }

        self.state.full_hash = hash(pdumps(self.serialize()))

    def serialize(self) -> dict[str, object]:
        """Serialize Node Anchor."""
        return {
            **super().serialize(),
            "schedule": asdict(self.schedule) if self.schedule else None,
        }


@dataclass(eq=False, repr=False, kw_only=True)
class ObjectAnchor(BaseAnchor, _ObjectAnchor):  # type: ignore[misc]
    """Object Anchor."""

    archetype: "ObjectArchetype"

    class Collection(BaseCollection["ObjectAnchor"]):
        """ObjectAnchor collection interface."""

        __collection__: str | None = "object"
        __default_indexes__: list[dict] = [
            {"keys": [("_id", ASCENDING), ("name", ASCENDING), ("root", ASCENDING)]}
        ]

        @classmethod
        def __document__(cls, doc: Mapping[str, Any]) -> "ObjectAnchor":
            """Parse document to NodeAnchor."""
            doc = cast(dict, doc)

            archetype = archetype_to_dataclass(
                ObjectArchetype.__get_class__(doc.get("name") or "Root"),
                doc.pop("archetype"),
            )
            anchor = ObjectAnchor(
                archetype=archetype,
                id=doc.pop("_id"),
                access=Permission.deserialize(doc.pop("access")),
                state=AnchorState(connected=True),
                persistent=True,
                **doc,
            )
            archetype.__jac__ = anchor
            anchor.sync_hash()
            return anchor

    @classmethod
    def ref(cls, ref_id: str) -> "ObjectAnchor":
        """Return NodeAnchor instance if existing."""
        if match := NODE_ID_REGEX.search(ref_id):
            anchor = object.__new__(cls)
            anchor.name = str(match.group(1))
            anchor.id = ObjectId(match.group(2))
            return anchor
        raise ValueError(f"[{ref_id}] is not a valid reference!")

    def insert(
        self,
        bulk_write: BulkWrite,
    ) -> None:
        """Append Insert Query."""
        bulk_write.operations[ObjectAnchor].append(InsertOne(self.serialize()))

    def delete(self, bulk_write: BulkWrite) -> None:
        """Append Delete Query."""
        bulk_write.del_node(self.id)


class BaseArchetype:
    """Archetype Protocol."""

    __jac_classes__: dict[str, type["BaseArchetype"]]
    __jac_hintings__: dict[str, type]
    # __constraints__: type

    class __Constraints__:
        unique: list[tuple[str]]

    # __jac_indexes__: Iterable[Index] = []

    __jac__: Anchor

    def __serialize__(self) -> dict[str, Any]:
        """Process default serialization."""
        if is_dataclass(self) and not isinstance(self, type):
            return asdict(self)
        raise ValueError(
            f"{self.__jac__.__class__.__name__} {self.__class__.__name__} is not serializable!"
        )

    @classmethod
    def __ref_cls__(cls) -> str:
        """Get class naming."""
        return f"g:{cls.__name__}"

    @classmethod
    def __set_classes__(cls) -> dict[str, Any]:
        """Initialize Jac Classes."""
        jac_classes = {}
        for sub in cls.__subclasses__():
            sub.__jac_hintings__ = get_type_hints(sub)
            jac_classes[sub.__name__] = sub
        cls.__jac_classes__ = jac_classes
        return jac_classes

    @classmethod
    def __get_class__(cls: type[TBA], name: str) -> type[TBA]:
        """Build class map from subclasses."""
        jac_classes: dict[str, Any] | None = getattr(cls, "__jac_classes__", None)
        if not jac_classes or not (jac_class := jac_classes.get(name)):
            jac_classes = cls.__set_classes__()
            if (jac_class := jac_classes.get(name)) is None:
                logger.warning(
                    f"Can't find {cls.__name__} {name}. Defaulting to base {cls.__name__}."
                )
                return cls

        return jac_class


class NodeArchetype(BaseArchetype, _NodeArchetype):
    """Node Archetype Protocol."""

    __jac_base__: ClassVar[bool] = True

    @cached_property
    def __jac__(self) -> NodeAnchor:  # type: ignore[override]
        """Create default anchor."""
        return NodeAnchor(
            archetype=self,
            name=self.__class__.__name__,
            edges=[],
            access=Permission(),
            state=AnchorState(),
        )

    @classmethod
    def __ref_cls__(cls) -> str:
        """Get class naming."""
        return f"n:{cls.__name__}"

    @classmethod
    def __set_classes__(cls) -> dict[str, Any]:
        """Initialize Jac Classes."""
        jac_classes: dict[str, type[BaseArchetype]] = {}

        for sub in islice(cls.__subclasses__(), 1, None):
            sub.__jac_hintings__ = get_type_hints(sub)
            jac_classes[sub.__name__] = sub

        Root.__jac_hintings__ = get_type_hints(Root)
        jac_classes[""] = Root
        cls.__jac_classes__ = jac_classes
        return jac_classes


class EdgeArchetype(BaseArchetype, _EdgeArchetype):
    """Edge Archetype Protocol."""

    __jac_base__: ClassVar[bool] = True
    __jac__: EdgeAnchor

    @classmethod
    def __ref_cls__(cls) -> str:
        """Get class naming."""
        return f"e:{cls.__name__}"

    @classmethod
    def __set_classes__(cls) -> dict[str, Any]:
        """Initialize Jac Classes."""
        jac_classes: dict[str, type[BaseArchetype]] = {}

        for sub in islice(cls.__subclasses__(), 1, None):
            sub.__jac_hintings__ = get_type_hints(sub)
            jac_classes[sub.__name__] = sub

        GenericEdge.__jac_hintings__ = get_type_hints(GenericEdge)
        jac_classes[""] = GenericEdge
        cls.__jac_classes__ = jac_classes
        return jac_classes


class WalkerArchetype(BaseArchetype, _WalkerArchetype):
    """Walker Archetype Protocol."""

    __jac_base__: ClassVar[bool] = True

    @cached_property
    def __jac__(self) -> WalkerAnchor:  # type: ignore[override]
        """Create default anchor."""
        return WalkerAnchor(
            archetype=self,
            name=self.__class__.__name__,
            access=Permission(),
            state=WalkerAnchorState(),
        )

    @classmethod
    def __ref_cls__(cls) -> str:
        """Get class naming."""
        return f"w:{cls.__name__}"

    def __init_subclass__(cls) -> None:
        """Configure subclasses."""
        if not cls.__dict__.get("__jac_base__", False):
            from jac_cloud.plugin.implementation.api import populate_apis

            Jac.make_archetype(cls)
            WalkerAnchor.Collection.apply_partial_indexes(cls)
            populate_apis(cls)


class ObjectArchetype(BaseArchetype, _ObjectArchetype):
    """Object Archetype Protocol."""

    __jac_base__: ClassVar[bool] = True

    @cached_property
    def __jac__(self) -> ObjectAnchor:  # type: ignore[override]
        """Create default anchor."""
        return ObjectAnchor(
            archetype=self,
            name=self.__class__.__name__,
            access=Permission(),
            state=AnchorState(),
        )


@dataclass(eq=False)
class GenericEdge(EdgeArchetype):
    """Generic Root Node."""


@dataclass(eq=False)
class Root(NodeArchetype):
    """Generic Root Node."""

    def __init__(self) -> None:
        """Create node archetype."""
        self.__jac__ = NodeAnchor(
            archetype=self,
            edges=[],
            access=Permission(),
            state=AnchorState(),
        )
