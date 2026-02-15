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
import from jaclang.jac0core.constant { EdgeDir }
glob logger = getLogger(__name__),
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

    """Cast access level."""
    static def cast(val: int | str | AccessLevel) -> AccessLevel {
        if isinstance(val, int) {
            return AccessLevel(val);
        } elif isinstance(val, str) {
            return AccessLevel[val.upper()];
        } else {
            return val;
        }
    }
}

"""Access Structure."""
obj Access {
    has anchors: dict[(str, AccessLevel)] = field(default_factory=`dict);

    def check(self: Access, anchor: str) -> (AccessLevel | None);
}

"""Anchor Access Handler."""
obj Permission {
    has all: AccessLevel = AccessLevel.NO_ACCESS,
        roots: Access = field(default_factory=Access);
}

"""Report Handler."""
obj AnchorReport {
    has id: str,
        context: dict[(str, Any)];
}

glob ObjectSpatialFilter: TypeAlias = 'Callable[[Archetype], bool] | Archetype | list[Archetype] | None';

"""Object-Spatial Destination."""
@dataclass(eq=False, repr=False)
obj ObjectSpatialDestination {
    has direction: EdgeDir,
        `edge: (Callable[([Archetype], bool)] | None) = None,
        nd: (Callable[([Archetype], bool)] | None) = None;

    def edge_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool;
    def node_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool;
}

"""Object-Spatial Path."""
@dataclass(eq=False, repr=False)
obj ObjectSpatialPath {
    has origin: list[NodeArchetype],
        destinations: list[ObjectSpatialDestination],
        edge_only: bool,
        from_visit: bool;

    def init(
        self: ObjectSpatialPath,
        origin: (NodeArchetype | list[NodeArchetype]),
        destinations: (list[ObjectSpatialDestination] | None) = None
    ) -> None;

    def convert(
        self: ObjectSpatialPath, filter: ObjectSpatialFilter
    ) -> (Callable[([Archetype], bool)] | None);

    def append(
        self: ObjectSpatialPath,
        direction: EdgeDir,
        `edge: ObjectSpatialFilter,
        nd: ObjectSpatialFilter
    ) -> ObjectSpatialPath;

    def edge_out(
        self: ObjectSpatialPath,
        `edge: ObjectSpatialFilter = None,
        nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_in(
        self: ObjectSpatialPath,
        `edge: ObjectSpatialFilter = None,
        nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_any(
        self: ObjectSpatialPath,
        `edge: ObjectSpatialFilter = None,
        nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def set_edge_only(self: ObjectSpatialPath) -> ObjectSpatialPath;
    """Set edge only mode (alias for set_edge_only)."""
    def `edge(self: ObjectSpatialPath) -> ObjectSpatialPath {
        self.edge_only = True;
        return self;
    }

    """Set from visit mode."""
    def `visit(self: ObjectSpatialPath) -> ObjectSpatialPath {
        self.from_visit = True;
        return self;
    }

    with entry {
        set_visit = `visit;
    }

    def repr_builder(
        self: ObjectSpatialPath,
        repr_str: str,
        dest: ObjectSpatialDestination,
        mark: str
    ) -> str;

    def __repr__(self: ObjectSpatialPath) -> str;
}

"""Object Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
obj Anchor {
    has archetype: Archetype,
        id: UUID = field(default_factory=uuid4),
        `root: (UUID | None) = None,
        access: Permission = field(default_factory=Permission),
        persistent: bool = False,
        hash: int = 0;

    def is_populated(self: Anchor) -> bool;
    def make_stub(self: Anchor) -> TANCH;
    def populate(self: Anchor) -> None;
    def __getattr__(self: Anchor, name: str) -> object;
    def __getstate__(self: Anchor) -> dict[(str, Any)];
    def __setstate__(self: Anchor, state: dict[(str, Any)]) -> None;
    def __repr__(self: Anchor) -> str;
    def `report(self: Anchor) -> AnchorReport;
    def __hash__(self: Anchor) -> int;
    def __eq__(self: Anchor, other: object) -> bool;
}

"""Node Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
obj NodeAnchor(Anchor) {
    has archetype: NodeArchetype,
        edges: list[EdgeAnchor];

    def __getstate__(self: NodeAnchor) -> dict[(str, object)];
}

"""Edge Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
obj EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool;

    def __getstate__(self: EdgeAnchor) -> dict[(str, object)];
}

"""Walker Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
obj WalkerAnchor(Anchor) {
    has archetype: WalkerArchetype,
        path: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        next: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        ignores: list[NodeAnchor] = field(default_factory=`list),
        disengaged: bool = False;
}

"""Object Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
obj ObjectAnchor(Anchor) {
    has archetype: ObjectArchetype;
}

"""Archetype Protocol."""
@dataclass(eq=False, repr=False, kw_only=True)
obj Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
    }

    @cached_property
    def __jac__(self: Archetype) -> Anchor;

    def __init_subclass__(cls: Any, **kwargs: object) -> None;
    def __repr__(self: Archetype) -> str;
    def __jac_access__(self: Archetype) -> (AccessLevel | str | int | None);
}

"""Node Archetype Protocol."""
class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar = True;
    }

    """Create default anchor."""
    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor {
        return NodeAnchor(archetype=self, edges=[]);
    }
}

"""Edge Archetype Protocol."""
class EdgeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar = True;
        __jac__: EdgeAnchor;
    }
}

"""Walker Archetype Protocol."""
class WalkerArchetype(Archetype) {
    with entry {
        __jac_async__: ClassVar = False;
        __jac_base__: ClassVar = True;
        reports: list[Any] = field(default_factory=`list);
    }

    """Create default anchor."""
    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor {
        return WalkerAnchor(archetype=self);
    }
}

"""Object Archetype Protocol."""
class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar = True;
    }

    """Create default anchor."""
    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor {
        return ObjectAnchor(archetype=self);
    }
}

"""Generic Edge."""
@dataclass(eq=False)
obj GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar = True;
    }

    def __repr__(self: GenericEdge) -> str;
}

"""Generic Root Node."""
@dataclass(eq=False)
obj Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar = True;
    }

    @cached_property
    def __jac__(self: Root) -> NodeAnchor;

    def __repr__(self: Root) -> str;
}

"""Object-Spatial Function."""
@dataclass(eq=False)
obj ObjectSpatialFunction {
    has name: str,
        func: Callable[([Any, Any], Any)];

    @cached_property
    def trigger(
        self: ObjectSpatialFunction
    ) -> (type | UnionType | tuple[((type | UnionType), ...)] | None);
}

"""JSX Element representation."""
@dataclass(eq=False)
obj JsxElement {
    has tag: object,
        `props: dict[(str, object)],
        children: list;
}
