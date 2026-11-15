import from collections.abc { Callable }
import from functools { cached_property }
import from inspect { Parameter, _empty, signature }
import from logging { getLogger }
import from pickle { dumps }
import from threading { Lock }
import from types { UnionType }
import from typing { ClassVar, TypeVar }
import from uuid { UUID, uuid4 }
import weakref;
glob logger = getLogger(__name__),
     TARCH = TypeVar('TARCH', bound='Archetype'),
     TANCH = TypeVar('TANCH', bound='Anchor'),
     T = TypeVar('T');

glob _NO_TRIGGER = object(),
     _subclass_hook_lock = Lock();

glob _light_edge_types: dict[type, bool] = {},
     _edge_ctor_args: dict[type, tuple[str, ...]] = {},
     _edge_subtypes: dict[type, tuple[type, ...]] = {},
     _tracked_classes: dict[type, type] = {};

enum AccessLevel { NO_ACCESS = -1, READ = 0, CONNECT = 1, WRITE = 2 }

def access_level_cast(val: int | str | AccessLevel) -> AccessLevel;

obj Access {
    has anchors: dict[(str, AccessLevel)] = {};

    def check(anchor: str) -> (AccessLevel | None);
}

obj Permission {
    has all: AccessLevel = AccessLevel.NO_ACCESS,
        roots: Access = Access(),
        groups: Access = Access();
}

obj PermissionDenied {
    has operation: str,
        target_id: str,
        target_type: str,
        target_owner: (str | None),
        required: AccessLevel,
        actual: AccessLevel;

    def __eq__(other: object) -> bool;
    def to_dict -> dict[(str, any)];
    def message -> str;
}

obj AnchorReport {
    has id: str,
        context: dict[(str, any)];
}


obj Anchor {
    has archetype: Archetype,
        id: (UUID | None) = ObjectField(`init=False, `default=None),
        `root: (UUID | None) = ObjectField(`init=False, `default=None),
        access: (Permission | None) = ObjectField(`init=False, `default=None),
        _persistent: bool = ObjectField(`init=False, `default=False),
        destroyed: bool = ObjectField(`init=False, `default=False),
        hash: int = ObjectField(`init=False, `default=0);

    has persistent: bool { getter; setter(persistent: bool); }

    def ensure_id -> UUID;
    def own_access -> Permission;
    def is_populated -> bool;
    def make_stub -> TANCH;
    def populate -> None;
    def __getattr__(name: str) -> object;
    def __getstate__ -> dict[(str, any)];
    def __setstate__(state: dict[(str, any)]) -> None;
    def __repr__ -> str;
    def `report -> AnchorReport;
    def __hash__ -> int;
    def __eq__(other: object) -> bool;
}

obj NodeAnchor(Anchor) {
    has archetype: NodeArchetype,
        edges: list[EdgeAnchor],
        version: int = ObjectField(`init=False, `default=0),
        out_light: (dict[type, list[any]] | None) = ObjectField(
            `init=False, `default=None
        ),
        in_light: (dict[type, any] | None) = ObjectField(`init=False, `default=None),
        mixed: bool = ObjectField(`init=False, `default=False);

    def __getstate__ -> dict[(str, object)];
    def __getattr__(name: str) -> object;
    def is_populated -> bool;
    def edge_delta -> (tuple[(set[UUID], set[UUID])] | None);
    def remove_edge(`edge: EdgeAnchor) -> None;
    def all_edges -> list[EdgeAnchor];
    def loaded_edges -> list[EdgeAnchor];
    def has_heavy_edges -> bool;
    def detach_light -> None;
}

obj EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool,
        light: bool = ObjectField(`init=False, `default=False);

    def is_populated -> bool;
    def __getstate__ -> dict[(str, object)];
    def detach -> None;
}

obj WalkerAnchor(Anchor) {
    has archetype: WalkerArchetype,
        path: list[(NodeAnchor | EdgeAnchor)] = [],
        next: list[(NodeAnchor | EdgeAnchor)] = [],
        ignores: list[NodeAnchor] = [],
        disengaged: bool = False;
}

obj ObjectAnchor(Anchor) {
    has archetype: ObjectArchetype;
}

def same_anchor(a: (Anchor | None), b: (Anchor | None)) -> bool;

def anchor_key(anchor: Anchor) -> any;

obj Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _subclass_hooks: ClassVar[tuple[Callable[[type], None], ...]] = ();
    }

    @cached_property
    def __jac__ -> Anchor;

    def __init_subclass__(cls: any, **kwargs: object) -> None;
    static def install_subclass_hook(hook: Callable[[type], None]) -> None;
    static def uninstall_subclass_hook(hook: Callable[[type], None]) -> None;
    static def _subclass_tree -> list[type];
    def postinit -> None;
    def __repr__ -> str;
    def __jac_access__ -> (AccessLevel | str | int | None);
}

class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor;
}

class EdgeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
        __jac__: EdgeAnchor;
    }

    def __eq__(other: object) -> bool;
    def __hash__ -> int;
}

@make_object
class WalkerArchetype(Archetype) {
    has reports: list[any] = ObjectField(
        default_factory=`list, `init=False, repr=False
    );

    with entry {
        __jac_async__: ClassVar[bool] = False;
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor;
}

class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor;
}

obj GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    def __repr__ -> str;
}

obj Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__ -> NodeAnchor;

    def __getattr__(name: str) -> Root;
    def __repr__ -> str;
}

obj ObjectSpatialFunction {
    has name: str,
        func: Callable[([any, any], any)],
        trigger_override: any = _NO_TRIGGER;

    @cached_property
    def trigger -> (type | UnionType | tuple[((type | UnionType), ...)] | None);
}

obj JsxElement {
    has tag: object,
        `props: dict[(str, object)],
        children: list[any];
}


def is_light_edge_type(cls: type) -> bool;

def edge_ctor_args(cls: type) -> tuple[str, ...];

def new_connect_edge(
    ct: (type[EdgeArchetype] | EdgeArchetype),
    conn_assign: (tuple[(tuple[any, ...], tuple[any, ...])] | None)
) -> tuple[EdgeArchetype, tuple[str, ...]];

def edge_subtypes(cls: type) -> tuple[type, ...];

def _as_refs(held: any) -> any;

def _deref(lst: any) -> list[any];

glob _VACANT = weakref.ref(`type('_Vacated', (), {})()),
     _INDEX_AT: int = 64;

class _InLinks(list) {
    static has __slots__: tuple[str, ...] = ("at", "live", "limit");
    has at: dict[int, list[int]],
        live: int,
        limit: int;

    def init(self: _InLinks, refs: list[any]);
    def _rebuild(self: _InLinks, refs: list[any]);
    def add(self: _InLinks, src: NodeArchetype);
    def drop(self: _InLinks, src: NodeArchetype) -> bool;
}

def _connect_back(inn: dict[type, any], cls: type, src: NodeArchetype);

def _drop_back(d: (dict[type, any] | None), cls: type, src: NodeArchetype) -> bool;

def light_connect(src: NodeAnchor, cls: type, tgt: NodeAnchor);

def _drop_entry(d: (dict[type, list[any]] | None), cls: type, key: any) -> bool;

def light_disconnect(src: NodeAnchor, cls: type, tgt: NodeAnchor) -> bool;

def light_clear(anchor: NodeAnchor, cls: type, outgoing: bool = True) -> bool;

def light_clear_matching(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> bool;

def _collect_light(d: dict[type, list[any]], cls: (type | None)) -> list[any];

def light_out(anchor: NodeAnchor, cls: (type | None)) -> list[any];

def light_in(anchor: NodeAnchor, cls: (type | None)) -> list[any];

def light_hop(
    anchor: NodeAnchor, dir: int, cls: (type | None), edges_only: bool
) -> list[any];

def light_hop_answers(anchor: NodeAnchor, cls: (type | None)) -> bool;

def light_clear_hop(anchor: NodeAnchor, dir: int, cls: (type | None)) -> bool;

def light_edge_view(
    cls: type[EdgeArchetype], src: NodeAnchor, tgt: NodeAnchor
) -> EdgeArchetype;

def light_edge_views(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> list[EdgeAnchor];

def _note_write(an: any);

def _dirty_setattr(self: any, name: str, value: any) -> None;

def _dirty_delattr(self: any, name: str) -> None;

def untracked_class(cls: type[Archetype]) -> type[Archetype];

def _untracked_new(cls: type[Archetype]) -> Archetype;

def _tracked_reduce_ex(
    self: any, protocol: int
) -> tuple[Callable, tuple[type], dict[str, any]];

def track_writes(arch: Archetype) -> None;
