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
with entry {
    logger = getLogger(__name__);
    TARCH = TypeVar('TARCH', bound='Archetype');
    TANCH = TypeVar('TANCH', bound='Anchor');
    T = TypeVar('T');
}

"""Access level enum."""
class AccessLevel(IntEnum) {
    with entry {
        NO_ACCESS = -1;
        READ = 0;
        CONNECT = 1;
        WRITE = 2;
    }

    """Cast access level."""
    static def cast(val: ((int | str) | AccessLevel)) -> AccessLevel {
        match val {
            case int():
                return AccessLevel(val);

            case str():
                return AccessLevel[val.upper()];

            case _:
                return val;

        }
    }
}

"""Access Structure."""
@dataclass
class Access {
    with entry {
        anchors: <>dict[(str, AccessLevel)] = field(default_factory=<>dict);
    }

    """Validate access."""
    def check(self: Access, anchor: str) -> (AccessLevel | None) {
        return self.anchors.get(anchor);
    }
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

with entry {
    ObjectSpatialFilter: TypeAlias = 'Callable[[Archetype], bool] | Archetype | list[Archetype] | None';
}

"""Object-Spatial Destination."""
@dataclass(eq=False, repr=False)
class ObjectSpatialDestination {
    with entry {
        direction: EdgeDir;
        <>edge: (Callable[([Archetype], bool)] | None) = None;
        <>node: (Callable[([Archetype], bool)] | None) = None;
    }

    """Filter edge."""
    def edge_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool {
        return (not self.edge or self.edge(arch));
    }

    """Filter node."""
    def node_filter(self: ObjectSpatialDestination, arch: Archetype) -> bool {
        return (not self.node or self.node(arch));
    }
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

    """Override Init."""
    def __init__(
        self: ObjectSpatialPath,
        origin: (NodeArchetype | <>list[NodeArchetype]),
        destinations: (<>list[ObjectSpatialDestination] | None) = None
    ) -> None {
        if not isinstance(origin, <>list) {
            origin = [origin];
        }
        self.origin = origin;
        self.destinations = [] if (destinations is None) else destinations;
        self.edge_only = False;
        self.from_visit = False;
    }

    """Convert filter."""
    def convert(
        self: ObjectSpatialPath, filter: ObjectSpatialFilter
    ) -> (Callable[([Archetype], bool)] | None) {
        if not filter {
            return None;
        }
        if callable(filter) {
            return filter;
        } elif isinstance(filter, <>list) {
            return lambda  i: Any: (i in filter);
        }
        return lambda  i: Any: (i == filter);
    }

    """Append destination."""
    def append(
        self: ObjectSpatialPath,
        direction: EdgeDir,
        <>edge: ObjectSpatialFilter,
        <>node: ObjectSpatialFilter
    ) -> ObjectSpatialPath {
        self.destinations.append(
            ObjectSpatialDestination(
                direction, self.convert(<>edge), self.convert(<>node)
            )
        );
        return self;
    }

    """Override greater than function."""
    def edge_out(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath {
        return self.append(EdgeDir.OUT, <>edge, <>node);
    }

    """Override greater than function."""
    def edge_in(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath {
        return self.append(EdgeDir.IN, <>edge, <>node);
    }

    """Override greater than function."""
    def edge_any(
        self: ObjectSpatialPath,
        <>edge: ObjectSpatialFilter = None,
        <>node: ObjectSpatialFilter = None
    ) -> ObjectSpatialPath {
        return self.append(EdgeDir.ANY, <>edge, <>node);
    }

    """Set edge only."""
    def <>edge(self: ObjectSpatialPath) -> ObjectSpatialPath {
        self.edge_only = True;
        return self;
    }

    """Set from visit."""
    def <>visit(self: ObjectSpatialPath) -> ObjectSpatialPath {
        self.from_visit = True;
        return self;
    }

    """Repr builder."""
    def repr_builder(
        self: ObjectSpatialPath, repr: str, dest: ObjectSpatialDestination, mark: str
    ) -> str {
        repr += mark;
        repr += f" (edge{' filter' if dest.edge else ''}) ";
        repr += mark;
        repr += f" (node{' filter' if dest.node else ''}) ";
        return repr;
    }

    """Override repr."""
    def __repr__(self: ObjectSpatialPath) -> str {
        repr = 'nodes ';
        for dest in self.destinations {
            match dest.direction {
                case EdgeDir.IN:
                    repr = self.repr_builder(repr, dest, '<<');

                case EdgeDir.OUT:
                    repr = self.repr_builder(repr, dest, '>>');

                case _:
                    repr = self.repr_builder(repr, dest, '--');

            }
        }
        return repr.strip();
    }
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

    """Check if state."""
    def is_populated(self: Anchor) -> bool {
        return ('archetype' in self.__dict__);
    }

    """Return unsynced copy of anchor."""
    def make_stub(self: Anchor) -> TANCH {
        if self.is_populated() {
            unloaded = object.__new__(self.__class__);
            unloaded.id = self.id;
            return unloaded;
        }
        return self;
    }

    """Retrieve the Archetype from db and return."""
    def populate(self: Anchor) -> None {
        import from jaclang { JacRuntimeInterface as Jac }
        jsrc = Jac.get_context().mem;
        if (anchor := jsrc.find_by_id(self.id)) {
            self.__dict__.update(anchor.__dict__);
        }
    }

    """Trigger load if detects unloaded state."""
    def __getattr__(self: Anchor, name: str) -> object {
        if not self.is_populated() {
            self.populate();
            if not self.is_populated() {
                raise ValueError(
                    f"{self.__class__.__name__} [{self.id}] is not a valid reference!"
                ) ;
            }
            return getattr(self, name);
        }
        raise AttributeError(
            f"'{self.__class__.__name__} object has not attribute {name}'"
        ) ;
    }

    """Serialize Anchor."""
    def __getstate__(self: Anchor) -> <>dict[str, Any] {
        if self.is_populated() {
            unlinked = object.__new__(self.archetype.__class__);
            unlinked.__dict__.update(self.archetype.__dict__);
            unlinked.__dict__.pop('__jac__', None);
            return {
                'id': self.id,
                'archetype': unlinked,
                'root': self.root,
                'access': self.access,
                'persistent': self.persistent
            };
        } else {
            return {'id': self.id};
        }
    }

    """Deserialize Anchor."""
    def __setstate__(self: Anchor, state: <>dict[(str, Any)]) -> None {
        self.__dict__.update(state);
        if (self.is_populated() and self.archetype) {
            self.archetype.__jac__ = self;
            self.hash = hash(dumps(self));
        }
    }

    """Override representation."""
    def __repr__(self: Anchor) -> str {
        if self.is_populated() {
            attrs = '';
            for f in fields(self) {
                if (f.name in self.__dict__) {
                    attrs += f"{f.name}={self.__dict__[f.name]}, ";
                }
            }
            attrs = attrs[:-2];
        } else {
            attrs = f"id={self.id}";
        }
        return f"{self.__class__.__name__}({attrs})";
    }

    """Report Anchor."""
    def <>report(self: Anchor) -> AnchorReport {
        return AnchorReport(
            id=self.id.hex,
            context=asdict(self.archetype)
            if (
                is_dataclass(self.archetype) and not isinstance(self.archetype, <>type)
            )
            else {}
        );
    }

    """Override hash for anchor."""
    def __hash__(self: Anchor) -> int {
        return hash(self.id);
    }

    """Override equal implementation."""
    def __eq__(self: Anchor, other: object) -> bool {
        if isinstance(other, Anchor) {
            return ((self.__class__ is other.__class__) and (self.id == other.id));
        }
        return False;
    }
}

"""Node Anchor."""
@dataclass(eq=False, repr=False, kw_only=True)
class NodeAnchor(Anchor) {
    with entry {
        archetype: NodeArchetype;
        edges: <>list[EdgeAnchor];
    }

    """Serialize Node Anchor."""
    def __getstate__(self: NodeAnchor) -> <>dict[str, object] {
        state = super.__getstate__();
        if self.is_populated() {
            state['edges'] = [<>edge.make_stub() for <>edge in self.edges];
        }
        return state;
    }
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

    """Serialize Node Anchor."""
    def __getstate__(self: EdgeAnchor) -> <>dict[str, object] {
        state = super.__getstate__();
        if self.is_populated() {
            state.update(
                {
                    'source': self.source.make_stub(),
                    'target': self.target.make_stub(),
                    'is_undirected': self.is_undirected
                }
            );
        }
        return state;
    }
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

    """Create default anchor."""
    @cached_property
    def __jac__(self: Archetype) -> Anchor {
        return Anchor(archetype=self);
    }

    """Configure subclasses."""
    def __init_subclass__(cls: Any) -> None {
        if not cls.__dict__.get('__jac_base__', False) {
            import from jaclang { JacRuntimeInterface as _ }
            _.make_archetype(cls);
        }
    }

    """Override repr for archetype."""
    def __repr__(self: Archetype) -> str {
        return f"{self.__class__.__name__}";
    }

    """Override access validation."""
    def __jac_access__(self: Archetype) -> (((AccessLevel | str) | int) | None) {
        return None;
    }
}

"""Node Archetype Protocol."""
class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
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

    """Create default anchor."""
    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor {
        return WalkerAnchor(archetype=self);
    }
}

"""Walker Archetype Protocol."""
class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    """Create default anchor."""
    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor {
        return ObjectAnchor(archetype=self);
    }
}

"""Generic Edge."""
@dataclass(eq=False)
class GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    """Override repr for archetype."""
    def __repr__(self: GenericEdge) -> str {
        return f"{self.__class__.__name__}()";
    }
}

"""Generic Root Node."""
@dataclass(eq=False)
class Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    """Create default anchor."""
    @cached_property
    def __jac__(self: Root) -> NodeAnchor {
        return NodeAnchor(archetype=self, persistent=True, edges=[]);
    }

    """Override repr for archetype."""
    def __repr__(self: Root) -> str {
        return f"{self.__class__.__name__}()";
    }
}

"""Object-Spatial Function."""
@dataclass(eq=False)
class ObjectSpatialFunction {
    with entry {
        name: str;
        func: Callable[([Any, Any], Any)];
    }

    """Get function parameter annotations."""
    @cached_property
    def trigger(
        self: ObjectSpatialFunction
    ) -> (((<>type | UnionType) | <>tuple[((<>type | UnionType), ...)]) | None) {
        parameters = signature(self.func, eval_str=True).parameters;
        if (len(parameters) >= 2) {
            second_param = <>list(parameters.values())[1];
            ty = second_param.annotation;
            return ty if (ty != _empty) else None;
        }
        return None;
    }
}
