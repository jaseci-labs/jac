"""Core constructs for Jac Language."""
import from collections.abc { Callable }
import from dataclasses { asdict, dataclass, field, fields, is_dataclass }
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
enum AccessLevel {
    NO_ACCESS = -1,
    READ = 0,
    CONNECT = 1,
    WRITE = 2
}

"""Cast an int, str, or AccessLevel to AccessLevel."""
def access_level_cast(val: int | str | AccessLevel) -> AccessLevel {
    if isinstance(val, AccessLevel) {
        return val;
    }
    if isinstance(val, str) {
        val = val.upper();
    }
    _map: dict = {
        -1: AccessLevel.NO_ACCESS,
        0: AccessLevel.READ,
        1: AccessLevel.CONNECT,
        2: AccessLevel.WRITE,
        "NO_ACCESS": AccessLevel.NO_ACCESS,
        "READ": AccessLevel.READ,
        "CONNECT": AccessLevel.CONNECT,
        "WRITE": AccessLevel.WRITE
    };
    return _map[val];
}

"""Access Structure."""
obj Access {
    has anchors: dict[(str, AccessLevel)] = field(default_factory=`dict);

    def check(anchor: str) -> (AccessLevel | None);
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


"""Object Anchor."""
obj Anchor {
    has archetype: Archetype,
        id: UUID = field(default_factory=uuid4),
        root: (UUID | None) = None,
        access: Permission = field(default_factory=Permission),
        persistent: bool = False,
        hash: int = 0;

    def is_populated -> bool;
    def make_stub -> TANCH;
    def populate -> None;
    def __getattr__(name: str) -> object;
    def __getstate__ -> dict[(str, Any)];
    def __setstate__(state: dict[(str, Any)]) -> None;
    def __repr__ -> str;
    def `report -> AnchorReport;
    def __hash__ -> int;
    def __eq__(other: object) -> bool;
}

"""Node Anchor."""
obj NodeAnchor(Anchor) {
    has archetype: NodeArchetype,
        edges: list[EdgeAnchor],
        topology_index_data: (bytes | None) = None;

    def __getstate__ -> dict[(str, object)];
    def is_populated -> bool;
    def get_topology_index -> Any;
    def set_topology_index(index: Any) -> None;
}

"""Edge Anchor."""
obj EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool;

    def is_populated -> bool;
    def __getstate__ -> dict[(str, object)];
}

"""Walker Anchor."""
obj WalkerAnchor(Anchor) {
    has archetype: WalkerArchetype,
        path: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        next: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        ignores: list[NodeAnchor] = field(default_factory=`list),
        disengaged: bool = False;
}

"""Object Anchor."""
obj ObjectAnchor(Anchor) {
    has archetype: ObjectArchetype;
}

"""Archetype Protocol."""
obj Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _subclass_hooks: ClassVar[list[Callable[[type], None]]] = [];
    }

    @cached_property
    def __jac__ -> Anchor;

    def __init_subclass__(cls: Any, **kwargs: object) -> None;
    def __setattr__(name: str, value: Any) -> None;
    def __repr__ -> str;
    def __jac_access__ -> (AccessLevel | str | int | None);
}

"""Node Archetype Protocol."""
class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor {
        return NodeAnchor(archetype=self, edges=[]);
    }
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
        reports: list[Any] = field(default_factory=`list);
    }

    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor {
        return WalkerAnchor(archetype=self);
    }
}

"""Object Archetype Protocol."""
class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor {
        return ObjectAnchor(archetype=self);
    }
}

"""Generic Edge."""
obj GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    def __repr__ -> str;
}

"""Generic Root Node."""
obj Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__ -> NodeAnchor;

    def __repr__ -> str;
}

"""Object-Spatial Function."""
obj ObjectSpatialFunction {
    has name: str,
        func: Callable[([Any, Any], Any)];

    @cached_property
    def trigger -> (type | UnionType | tuple[((type | UnionType), ...)] | None);
}

"""JSX Element representation."""
obj JsxElement {
    has tag: object,
        `props: dict[(str, object)],
        children: list;
}

glob ObjectSpatialFilter: TypeAlias = Callable[[Archetype], bool] | Archetype | list[
         Archetype
     ] | None;

"""Object-Spatial Destination."""
obj ObjectSpatialDestination {
    has direction: EdgeDir,
        `edge: (Callable[([Archetype], bool)] | None) = None,
        nd: (Callable[([Archetype], bool)] | None) = None;

    def edge_filter(arch: Archetype) -> bool;
    def node_filter(arch: Archetype) -> bool;
}

"""Object-Spatial Path."""
obj ObjectSpatialPath {
    has origin: list[NodeArchetype],
        destinations: list[ObjectSpatialDestination],
        edge_only: bool,
        from_visit: bool;

    def init(
        origin: (NodeArchetype | list[NodeArchetype]),
        destinations: (list[ObjectSpatialDestination] | None) = None
    ) -> None;

    def convert(filter: ObjectSpatialFilter) -> (Callable[([Archetype], bool)] | None);
    def append(
        direction: EdgeDir, `edge: ObjectSpatialFilter, nd: ObjectSpatialFilter
    ) -> ObjectSpatialPath;

    def edge_out(
        `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_in(
        `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def edge_any(
        `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath;

    def set_edge_only -> ObjectSpatialPath;
    def `edge -> ObjectSpatialPath {
        self.edge_only = True;
        return self;
    }

    def `visit -> ObjectSpatialPath {
        self.from_visit = True;
        return self;
    }

    with entry {
        set_visit = `visit;
    }

    def repr_builder(repr_str: str, dest: ObjectSpatialDestination, mark: str) -> str;
    def __repr__ -> str;
}
