"""Core constructs for Jac Language."""
import from collections.abc { Callable }
import from dataclasses { asdict, dataclass, field, fields, is_dataclass }
import from enum { IntEnum }
import from functools { cached_property }
import from inspect { _empty, signature }
import from logging { getLogger }
import from pickle { dumps }
import from types { UnionType }
import from typing { Any, ClassVar, TypeAlias, TypeVar }
import from uuid { UUID, uuid4 }
import from ..pycore.constant { EdgeDir }

glob
    logger = getLogger(__name__),
    TARCH = TypeVar('TARCH', bound='Archetype'),
    TANCH = TypeVar('TANCH', bound='Anchor'),
    T = TypeVar('T');

"""Access level enum."""
class AccessLevel(IntEnum) {
    with entry {
        NO_ACCESS = -1;
        READ = 0;
        CONNECT = 1;
        WRITE = 2;
    }

    static def cast(val: ((int | str) | AccessLevel)) -> AccessLevel;
}

"""Access Structure."""
@dataclass
class Access {
    with entry {
        anchors: <>dict[(str, AccessLevel)] = field(default_factory=<>dict);
    }

    def check(self: Access, anchor: str) -> (AccessLevel | None);
}

"""Anchor Access Handler."""
@dataclass
class Permission {
    with entry {
        all: AccessLevel = AccessLevel.NO_ACCESS;
        roots: Access = field(default_factory=Access);
    }
}

"""Report Handler."""
@dataclass
class AnchorReport {
    with entry {
        id: str;
        context: <>dict[(str, Any)];
    }
}

glob ObjectSpatialFilter: TypeAlias = 'Callable[[Archetype], bool] | Archetype | list[Archetype] | None';

"""Object-Spatial Destination."""
@dataclass(eq=False, repr=False)
class ObjectSpatialDestination {
    with entry {
        direction: EdgeDir;
        <>edge: (Callable[([Archetype], bool)] | None) = None;
        <>node: (Callable[([Archetype], bool)] | None) = None;
    }

    def edge_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool;
    def node_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool;
}

"""Object-Spatial Path."""
@dataclass(eq=False, repr=False)
class ObjectSpatialPath {
    with entry {
        origin: <>list[NodeArchetype];
        destinations: <>list[ObjectSpatialDestination];
        edge_only: bool;
        from_visit: bool;
    }

    def init(
        self: ObjectSpatialPath,
        origin: (NodeArchetype | <>list[NodeArchetype]),
        destinations: (<>list[ObjectSpatialDestination] | None) = None
    ) -> None;

    def convert(
        self: ObjectSpatialPath, filter: ObjectSpatialFilter
    ) -> (Callable[([Archetype], bool)] | None);

    def append(
        self: ObjectSpatialPath,
        direction: EdgeDir,
        <>edge: ObjectSpatialFilter,
        <>node: ObjectSpatialFilter
    ) -> ObjectSpatialPath;

    def edge_out(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_in(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_any(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def <>edge(self: ObjectSpatialPath) -> ObjectSpatialPath;
    def <>visit(self: ObjectSpatialPath) -> ObjectSpatialPath;
    def repr_builder(
        self: ObjectSpatialPath, repr: str, dest: ObjectSpatialDestination, mark: str
    ) -> str;

    def __repr__(self: ObjectSpatialPath) -> str;
}

"""Object Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class Anchor {
    with entry {
        archetype: Archetype;
        id: UUID = field(default_factory=uuid4);
        <>root: (UUID | None) = None;
        access: Permission = field(default_factory=Permission);
        persistent: bool = False;
        hash: int = 0;
    }

    def is_populated(self: Anchor) -> bool;
    def make_stub(self: Anchor) -> TANCH;
    def populate(self: Anchor) -> None;
    def __getattr__(self: Anchor, name: str) -> object;
    def __getstate__(self: Anchor) -> <>dict[str, Any];
    def __setstate__(self: Anchor, state: <>dict[(str, Any)]) -> None;
    def __repr__(self: Anchor) -> str;
    def <>report(self: Anchor) -> AnchorReport;
    def __hash__(self: Anchor) -> int;
    def __eq__(self: Anchor, other: object) -> bool;
}

"""Node Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class NodeAnchor(Anchor) {
    with entry {
        archetype: NodeArchetype;
        edges: <>list[EdgeAnchor];
    }

    def __getstate__(self: NodeAnchor) -> <>dict[str, object];
}

"""Edge Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class EdgeAnchor(Anchor) {
    with entry {
        archetype: EdgeArchetype;
        source: NodeAnchor;
        target: NodeAnchor;
        is_undirected: bool;
    }

    def __getstate__(self: EdgeAnchor) -> <>dict[str, object];
}

"""Walker Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class WalkerAnchor(Anchor) {
    with entry {
        archetype: WalkerArchetype;
        path: <>list[NodeAnchor] = field(default_factory=<>list);
        next: <>list[(NodeAnchor | EdgeAnchor)] = field(default_factory=<>list);
        ignores: <>list[NodeAnchor] = field(default_factory=<>list);
        disengaged: bool = False;
    }
}

"""Edge Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class ObjectAnchor(Anchor) {
    with entry {
        archetype: ObjectArchetype;
    }
}

"""Archetype Protocol."""
@dataclass(eq=False, repr=False, kw_only=True)
class Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[<>list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[<>list[ObjectSpatialFunction]] = [];
    }

    @cached_property
    def __jac__(self: Archetype) -> Anchor;

    def __init_subclass__(cls: Any) -> None;
    def __repr__(self: Archetype) -> str;
    def __jac_access__(self: Archetype) -> (((AccessLevel | str) | int) | None);
}

"""Node Archetype Protocol."""
class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor;
}

"""Edge Archetype Protocol."""
class EdgeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
        __jac__: EdgeAnchor;
    }
}

"""Walker Archetype Protocol."""
class WalkerArchetype(Archetype) {
    with entry {
        __jac_async__: ClassVar[bool] = False;
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor;
}

"""Walker Archetype Protocol."""
class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor;
}

"""Generic Edge."""
@dataclass(eq=False)
class GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    def __repr__(self: GenericEdge) -> str;
}

"""Generic Root Node."""
@dataclass(eq=False)
class Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: Root) -> NodeAnchor;

    def __repr__(self: Root) -> str;
}

"""Object-Spatial Function."""
@dataclass(eq=False)
class ObjectSpatialFunction {
    with entry {
        name: str;
        func: Callable[([Any, Any], Any)];
    }

    @cached_property
    def trigger(
        self: ObjectSpatialFunction
    ) -> (((<>type | UnionType) | <>tuple[((<>type | UnionType), ...)]) | None);
}
