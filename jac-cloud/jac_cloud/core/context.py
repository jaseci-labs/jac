"""Core constructs for Jac Language."""

from contextvars import ContextVar
from dataclasses import MISSING, dataclass, is_dataclass
from typing import Any, Generic, TypeVar, cast

from bson import ObjectId

from fastapi import Request, WebSocket

from jaclang.runtimelib.machine import ExecutionContext

from .archetype import (
    AccessLevel,
    Anchor,
    BaseArchetype,
    NodeAnchor,
    Root,
    asdict,
)
from .memory import MongoDB

JASECI_CONTEXT = ContextVar["JaseciContext | None"]("JaseciContext")

SUPER_ROOT_ID = ObjectId("000000000000000000000000")
PUBLIC_ROOT_ID = ObjectId("000000000000000000000001")
SUPER_ROOT = NodeAnchor.ref(f"n::{SUPER_ROOT_ID}")
PUBLIC_ROOT = NodeAnchor.ref(f"n::{PUBLIC_ROOT_ID}")

RT = TypeVar("RT")


@dataclass
class ContextResponse(Generic[RT]):
    """Default Context Response."""

    status: int
    reports: list[RT]


class JaseciContext(ExecutionContext):
    """Execution Context."""

    mem: MongoDB
    reports: list
    status: int
    system_root: NodeAnchor
    root_state: NodeAnchor
    entry_node: NodeAnchor
    connection: Request | WebSocket | None

    def __init__(self) -> None:
        """Initialize JacMachine."""
        # Temporary patch the initialization
        # Jac-Cloud context should not alawys hold JacMachine
        pass

    def close(self) -> None:
        """Clean up context."""
        self.mem.close()

    @staticmethod
    def create(  # type: ignore[override]
        connection: Request | WebSocket | None, entry: NodeAnchor | None = None
    ) -> "JaseciContext":
        """Create JacContext."""
        ctx = JaseciContext()
        ctx.connection = connection
        ctx.mem = MongoDB()
        ctx.reports = []
        ctx.status = 200
        ctx.custom = MISSING

        system_root: NodeAnchor | None = None
        system_root = ctx.mem.find_by_id(SUPER_ROOT)
        if not isinstance(system_root, NodeAnchor):
            system_root = Root().__jac__  # type: ignore[attr-defined]
            system_root.id = SUPER_ROOT_ID
            system_root.state.connected = True
            system_root.persistent = True
            NodeAnchor.Collection.insert_one(system_root.serialize())
            system_root.sync_hash()
            ctx.mem.set(system_root.id, system_root)

        ctx.system_root = system_root

        if connection is None:
            ctx.root_state = system_root
        elif _root := getattr(connection, "_root", None):
            ctx.root_state = _root
            ctx.mem.set(_root.id, _root)
        else:
            if not isinstance(
                public_root := ctx.mem.find_by_id(PUBLIC_ROOT), NodeAnchor
            ):
                public_root = Root().__jac__  # type: ignore[attr-defined]
                public_root.id = PUBLIC_ROOT_ID
                public_root.access.all = AccessLevel.WRITE
                public_root.persistent = True
                ctx.mem.set(public_root.id, public_root)

            ctx.root_state = public_root

        if entry:
            if not isinstance(entry_node := ctx.mem.find_by_id(entry), NodeAnchor):
                raise ValueError(f"Invalid anchor id {entry.ref_id} !")
            ctx.entry_node = entry_node
        else:
            ctx.entry_node = ctx.root_state

        if _ctx := JASECI_CONTEXT.get(None):
            _ctx.close()
        JASECI_CONTEXT.set(ctx)

        return ctx

    @staticmethod
    def get() -> "JaseciContext":
        """Get current JaseciContext."""
        if ctx := JASECI_CONTEXT.get(None):
            return ctx
        raise Exception("JaseciContext is not yet available!")

    @staticmethod
    def get_root() -> Root:  # type: ignore[override]
        """Get current root."""
        return cast(Root, JaseciContext.get().root_state.archetype)

    def response(self) -> dict[str, Any]:
        """Return serialized version of reports."""
        resp = ContextResponse[Any](status=self.status, reports=self.reports)

        for key, val in enumerate(self.reports):
            self.clean_response(key, val, self.reports)

        return asdict(resp)

    def clean_response(
        self, key: str | int, val: Any, obj: list | dict  # noqa: ANN401
    ) -> None:
        """Cleanup and override current object."""
        match val:
            case list():
                for idx, lval in enumerate(val):
                    self.clean_response(idx, lval, val)
            case dict():
                for key, dval in val.items():
                    self.clean_response(key, dval, val)
            case Anchor():
                cast(dict, obj)[key] = val.report()
            case BaseArchetype():
                cast(dict, obj)[key] = val.__jac__.report()
            case val if is_dataclass(val) and not isinstance(val, type):
                cast(dict, obj)[key] = asdict(val)
            case _:
                pass
