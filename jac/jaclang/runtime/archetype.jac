import from collections { OrderedDict }
import from collections.abc { Callable }
import from jaclang.runtime.object_model {
    asdict,
    field,
    fields,
    is_jac_object,
    make_object
}
import from functools { cached_property }
import from inspect { _empty, signature }
import from logging { getLogger }
import from pickle { dumps }
import from threading { Lock }
import from types { UnionType }
import from typing { ClassVar, TypeVar }
import from uuid { UUID, uuid4 }
import weakref;
import from jaclang.runtime.access_level { AccessLevel }
import from jaclang.compiler.frontend.constant { EdgeDir }
glob logger = getLogger(__name__),
     TARCH = TypeVar('TARCH', bound='Archetype'),
     TANCH = TypeVar('TANCH', bound='Anchor'),
     T = TypeVar('T');

glob _NO_TRIGGER = object(),
     _subclass_hook_lock = Lock();

glob _light_edge_types: dict[type, bool] = {},
     _edge_subtypes: dict[type, tuple] = {},
     _tracked_classes: dict[type, type] = {};

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

@make_object
class Access {
    has anchors: dict[(str, AccessLevel)] = field(default_factory=`dict);

    def check(self: Access, anchor: str) -> (AccessLevel | None);
}

@make_object
class Permission {
    has all: AccessLevel = AccessLevel.NO_ACCESS,
        roots: Access = field(default_factory=Access),
        groups: Access = field(default_factory=Access);
}

@make_object
class PermissionDenied {
    has operation: str,
        target_id: str,
        target_type: str,
        target_owner: (str | None),
        required: AccessLevel,
        actual: AccessLevel;

    def __eq__(self: PermissionDenied, other: object) -> bool {
        if not isinstance(other, PermissionDenied) or type(other) is not type(self) {
            return False;
        }
        return (
            self.operation,
            self.target_id,
            self.target_type,
            self.target_owner,
            self.required,
            self.actual
        )
            == (
                other.operation,
                other.target_id,
                other.target_type,
                other.target_owner,
                other.required,
                other.actual
            );
    }

    def to_dict(self: PermissionDenied) -> dict[(str, any)];
    def message(self: PermissionDenied) -> str;
}

@make_object
class AnchorReport {
    has id: str,
        context: dict[(str, any)];
}


@make_object
class Anchor {
    has archetype: Archetype,
        id: (UUID | None) = field(`init=False, `default=None),
        `root: (UUID | None) = field(`init=False, `default=None),
        access: (Permission | None) = field(`init=False, `default=None),
        _persistent: bool = field(`init=False, `default=False),
        destroyed: bool = field(`init=False, `default=False),
        hash: int = field(`init=False, `default=0);

    has persistent: bool { getter; setter(persistent: bool); }

    def ensure_id(self: Anchor) -> UUID;
    def own_access(self: Anchor) -> Permission;
    def is_populated(self: Anchor) -> bool;
    def make_stub(self: Anchor) -> TANCH;
    def populate(self: Anchor) -> None;
    def __getattr__(self: Anchor, name: str) -> object;
    def __getstate__(self: Anchor) -> dict[(str, any)];
    def __setstate__(self: Anchor, state: dict[(str, any)]) -> None;
    def __repr__(self: Anchor) -> str;
    def `report(self: Anchor) -> AnchorReport;
    def __hash__(self: Anchor) -> int;
    def __eq__(self: Anchor, other: object) -> bool;
}

@make_object
class NodeAnchor(Anchor) {
    has archetype: NodeArchetype,
        edges: list[EdgeAnchor],
        version: int = field(`init=False, `default=0),
        out_light: (dict[type, list] | None) = field(`init=False, `default=None),
        in_light: (dict[type, list] | None) = field(`init=False, `default=None),
        mixed: bool = field(`init=False, `default=False);

    def __getstate__(self: NodeAnchor) -> dict[(str, object)];
    def is_populated(self: NodeAnchor) -> bool;
    def edge_delta(self: NodeAnchor) -> (tuple[(set[UUID], set[UUID])] | None);
    def remove_edge(self: NodeAnchor, `edge: EdgeAnchor) -> None;
    def all_edges(self: NodeAnchor) -> list[EdgeAnchor];
    def has_heavy_edges(self: NodeAnchor) -> bool;
    def detach_light(self: NodeAnchor) -> None;
}

@make_object
class EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool,
        light: bool = field(`init=False, `default=False);

    def is_populated(self: EdgeAnchor) -> bool;
    def __getstate__(self: EdgeAnchor) -> dict[(str, object)];
    def detach(self: EdgeAnchor) -> None;
}

@make_object
class WalkerAnchor(Anchor) {
    has archetype: WalkerArchetype,
        path: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        next: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        ignores: list[NodeAnchor] = field(default_factory=`list),
        disengaged: bool = False;
}

@make_object
class ObjectAnchor(Anchor) {
    has archetype: ObjectArchetype;
}

def same_anchor(a: (Anchor | None), b: (Anchor | None)) -> bool {
    if a is b {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    aid = a.id;
    return aid is not None and aid == b.id;
}

def anchor_key(anchor: Anchor) -> any {
    aid = anchor.id;
    return aid if aid is not None else id(anchor);
}

@make_object
class Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _subclass_hooks: ClassVar[tuple[Callable[[type], None], ...]] = ();
    }

    @cached_property
    def __jac__(self: Archetype) -> Anchor;

    def __init_subclass__(cls: any, **kwargs: object) -> None;
    static def install_subclass_hook(hook: Callable[[type], None]) -> None;
    static def uninstall_subclass_hook(hook: Callable[[type], None]) -> None;
    static def _subclass_tree -> list[type];
    def postinit(self: Archetype) -> None;
    def __repr__(self: Archetype) -> str;
    def __jac_access__(self: Archetype) -> (AccessLevel | str | int | None);
}

class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor {
        return NodeAnchor(archetype=self, edges=[]);
    }
}

class EdgeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
        __jac__: EdgeAnchor;
    }

    def __eq__(self: EdgeArchetype, other: object) -> bool {
        if self is other {
            return True;
        }
        mine = self.__dict__.get('__jac__');
        theirs = other.__dict__.get('__jac__')
            if isinstance(other, EdgeArchetype)
            else None;
        if mine is None or theirs is None or not (mine.light and theirs.light) {
            return False;
        }
        return (
            `type(self) is `type(other)
            and mine.source is theirs.source
            and mine.target is theirs.target
        );
    }

    def __hash__(self: EdgeArchetype) -> int {
        mine = self.__dict__.get('__jac__');
        if mine is not None and mine.light {
            return hash((`type(self), id(mine.source), id(mine.target)));
        }
        return id(self);
    }
}

class WalkerArchetype(Archetype) {
    has reports: list[any] = field(default_factory=`list);

    with entry {
        __jac_async__: ClassVar[bool] = False;
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor {
        return WalkerAnchor(archetype=self);
    }
}

class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor {
        return ObjectAnchor(archetype=self);
    }
}

@make_object
class GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    def __repr__(self: GenericEdge) -> str;
}

@make_object
class Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: Root) -> NodeAnchor;

    def __getattr__(self: Root, name: str) -> Root;
    def __repr__(self: Root) -> str;
}

@make_object
class ObjectSpatialFunction {
    has name: str,
        func: Callable[([any, any], any)],
        trigger_override: any = _NO_TRIGGER;

    @cached_property
    def trigger(
        self: ObjectSpatialFunction
    ) -> (type | UnionType | tuple[((type | UnionType), ...)] | None);
}

@make_object
class JsxElement {
    has tag: object,
        `props: dict[(str, object)],
        children: list;
}


def is_light_edge_type(cls: type) -> bool {
    known = _light_edge_types.get(cls);
    if known is not None {
        return known;
    }
    light = isinstance(cls, `type) and issubclass(cls, EdgeArchetype);
    if light and is_jac_object(cls) {
        for f in fields(cls) {
            light = False;
            break;
        }
    }
    _light_edge_types[cls] = light;
    return light;
}

def edge_subtypes(cls: type) -> tuple {
    known = _edge_subtypes.get(cls);
    if known is not None {
        return known;
    }
    out: list = [cls];
    i = 0;
    while i < len(out) {
        for sub in out[i].__subclasses__() {
            if sub not in out and not sub.__dict__.get('__jac_tracked__', False) {
                out.append(sub);
            }
        }
        i += 1;
    }
    result = tuple(out);
    _edge_subtypes[cls] = result;
    return result;
}

def _deref(lst: list) -> list {
    out: list = [];
    for r in lst {
        a = r();
        if a is not None {
            out.append(a);
        }
    }
    return out;
}

def light_connect(src: NodeAnchor, cls: type, tgt: NodeAnchor) {
    out = src.out_light;
    if out is None {
        out = {};
        src.out_light = out;
    }
    lst = out.get(cls);
    if lst is None {
        out[cls] = [tgt.archetype];
    } else {
        lst.append(tgt.archetype);
    }
    inn = tgt.in_light;
    if inn is None {
        inn = {};
        tgt.in_light = inn;
    }
    back = weakref.ref(src.archetype);
    lst = inn.get(cls);
    if lst is None {
        inn[cls] = [back];
    } else {
        lst.append(back);
        if len(lst) & 63 == 0 {
            lst[:] = [
                r
                for r in lst
                if r() is not None
            ];
        }
    }
}

def _drop_entry(d: (dict | None), cls: type, key: any) -> bool {
    if d is None {
        return False;
    }
    lst = d.get(cls);
    if lst is None {
        return False;
    }
    try {
        lst.remove(key);
    } except ValueError {
        return False;
    }
    if not lst {
        d.pop(cls, None);
    }
    return True;
}

def light_disconnect(src: NodeAnchor, cls: type, tgt: NodeAnchor) -> bool {
    held = _drop_entry(src.out_light, cls, tgt.archetype);
    _drop_entry(tgt.in_light, cls, weakref.ref(src.archetype));
    return held;
}

def light_clear(anchor: NodeAnchor, cls: type, outgoing: bool = True) -> bool {
    d = anchor.out_light if outgoing else anchor.in_light;
    if d is None {
        return False;
    }
    lst = d.pop(cls, None);
    if not lst {
        return False;
    }
    me = anchor.archetype;
    if outgoing {
        back = weakref.ref(me);
        for other in lst {
            _drop_entry(other.__jac__.in_light, cls, back);
        }
    } else {
        for other in _deref(lst) {
            _drop_entry(other.__jac__.out_light, cls, me);
        }
    }
    return True;
}

def light_clear_matching(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> bool {
    d = anchor.out_light if outgoing else anchor.in_light;
    if not d {
        return False;
    }
    if cls is not None and len(_edge_subtypes.get(cls) or edge_subtypes(cls)) == 1 {
        return light_clear(anchor, cls, outgoing);
    }
    hit = False;
    for k in `list(d.keys()) {
        if cls is None or issubclass(k, cls) {
            if light_clear(anchor, k, outgoing) {
                hit = True;
            }
        }
    }
    return hit;
}

def _collect_light(d: dict, cls: (type | None)) -> list {
    if cls is None {
        out: list = [];
        for lst in d.values() {
            out.extend(lst);
        }
        return out;
    }
    subs = edge_subtypes(cls);
    if len(subs) == 1 {
        lst = d.get(cls);
        return lst if lst is not None else [];
    }
    found: list = [];
    if len(subs) <= len(d) {
        for sub in subs {
            lst = d.get(sub);
            if lst {
                found.extend(lst);
            }
        }
    } else {
        for (k, lst) in d.items() {
            if lst and issubclass(k, cls) {
                found.extend(lst);
            }
        }
    }
    return found;
}

def light_out(anchor: NodeAnchor, cls: (type | None)) -> list {
    d = anchor.out_light;
    return _collect_light(d, cls) if d else [];
}

def light_in(anchor: NodeAnchor, cls: (type | None)) -> list {
    d = anchor.in_light;
    return _deref(_collect_light(d, cls)) if d else [];
}

def light_hop(
    anchor: NodeAnchor, dir: int, cls: (type | None), edges_only: bool
) -> list {
    if edges_only {
        out: list = [];
        if dir != 1 {
            for ea in light_edge_views(anchor, cls, True) {
                out.append(ea.archetype);
            }
        }
        if dir != 2 {
            for ea in light_edge_views(anchor, cls, False) {
                out.append(ea.archetype);
            }
        }
        return out;
    }
    if cls is not None and len(_edge_subtypes.get(cls) or edge_subtypes(cls)) == 1 {
        if dir == 2 {
            d = anchor.out_light;
            lst = d.get(cls) if d else None;
            return `list(lst) if lst else [];
        }
        if dir == 1 {
            d = anchor.in_light;
            lst = d.get(cls) if d else None;
            return _deref(lst) if lst else [];
        }
        found: list = [];
        d = anchor.out_light;
        lst = d.get(cls) if d else None;
        if lst {
            found = `list(lst);
        }
        d = anchor.in_light;
        lst = d.get(cls) if d else None;
        if lst {
            found = found + _deref(lst);
        }
    } elif dir == 2 {
        found = light_out(anchor, cls);
    } elif dir == 1 {
        found = light_in(anchor, cls);
    } else {
        found = light_out(anchor, cls) + light_in(anchor, cls);
    }
    if len(found) < 2 {
        return `list(found);
    }
    return `list(`dict.fromkeys(found));
}

def light_hop_answers(anchor: NodeAnchor, cls: (type | None)) -> bool {
    if anchor.persistent {
        return False;
    }
    if not anchor.has_heavy_edges() {
        return True;
    }
    return cls is not None and not anchor.mixed and is_light_edge_type(cls);
}

def light_clear_hop(anchor: NodeAnchor, dir: int, cls: (type | None)) -> bool {
    hit = False;
    if dir != 1 and light_clear_matching(anchor, cls, True) {
        hit = True;
    }
    if dir != 2 and light_clear_matching(anchor, cls, False) {
        hit = True;
    }
    return hit;
}

def light_edge_view(
    cls: type[EdgeArchetype], src: NodeAnchor, tgt: NodeAnchor
) -> EdgeArchetype {
    e = cls.__new__(cls);
    ea = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False);
    ea.light = True;
    e.__jac__ = ea;
    return e;
}

def light_edge_views(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> list[EdgeAnchor] {
    d = anchor.out_light if outgoing else anchor.in_light;
    if not d {
        return [];
    }
    out: list[EdgeAnchor] = [];
    for (k, lst) in d.items() {
        if cls is not None and not issubclass(k, cls) {
            continue;
        }
        for other in (lst if outgoing else _deref(lst)) {
            oa = other.__jac__;
            e = light_edge_view(k, anchor, oa)
                if outgoing
                else light_edge_view(k, oa, anchor);
            out.append(e.__jac__);
        }
    }
    return out;
}

def _dirty_setattr(self: any, name: str, value: any) -> None {
    an = self.__dict__.get('__jac__');
    if an is None or not an.persistent {
        object.__setattr__(self, name, value);
        return;
    }
    import from jaclang.runtime.runtime { JacRuntime }
    ctx = JacRuntime.exec_ctx;
    if ctx is None {
        object.__setattr__(self, name, value);
        return;
    }
    import from jaclang { JacRuntimeInterface }
    if not JacRuntimeInterface.check_write_access(an, op_hint="field_write") {
        return;
    }
    object.__setattr__(self, name, value);
    md = ctx.mem?.mark_dirty;
    if md is not None {
        md(an);
    }
}

def untracked_class(cls: type[Archetype]) -> type[Archetype] {
    return cls.__dict__.get('__jac_untracked__', cls);
}

def _untracked_new(cls: type[Archetype]) -> Archetype {
    return object.__new__(cls);
}

def _tracked_reduce_ex(self: any, protocol: int) -> tuple {
    return (_untracked_new, (untracked_class(`type(self)), ), self.__dict__);
}

def track_writes(arch: Archetype) -> None {
    cls = `type(arch);
    if cls.__dict__.get('__jac_tracked__', False) {
        return;
    }
    tracked = _tracked_classes.get(cls);
    if tracked is None {
        tracked = `type(
            cls.__name__,
            (cls, ),
            {
                '__module__': cls.__module__,
                '__qualname__': cls.__qualname__,
                '__jac_base__': True,
                '__jac_tracked__': True,
                '__jac_untracked__': cls,
                '__setattr__': _dirty_setattr,
                '__reduce_ex__': _tracked_reduce_ex
            }
        );
        _tracked_classes[cls] = tracked;
    }
    object.__setattr__(arch, '__class__', tracked);
}

def make_archetype(cls: type[Archetype]) -> type[Archetype] {
    entries: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_entry_funcs_
    );
    exits: OrderedDict[(str, ObjectSpatialFunction)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_exit_funcs_
    );
    for func in cls.__dict__.values() {
        if callable(func) and (func?.__jac_entry or func?.__jac_exit) {
            dsfunc = ObjectSpatialFunction(func.__name__, func, func.__jac_trigger__)
                if func?.__jac_trigger__
                else ObjectSpatialFunction(func.__name__, func);
            if func?.__jac_entry {
                entries[func.__name__] = dsfunc;
            }
            if func?.__jac_exit {
                exits[func.__name__] = dsfunc;
            }
        }
    }
    cls._jac_entry_funcs_ = [*entries.values()];
    cls._jac_exit_funcs_ = [*exits.values()];
    if issubclass(cls, WalkerArchetype)
        and 'reports' not in cls.__dict__.get('__annotations__', {}) {
        if not hasattr(cls, '__annotations__') {
            cls.__annotations__ = {};
        }
        cls.__annotations__['reports'] = list;
        setattr(
            cls,
            'reports',
            field(default_factory=`list, init=False, repr=False, compare=False)
        );
    }
    if cls.__dict__.get('__annotations__') and not cls.__doc__ {
        cls.__doc__ = cls.__name__;
    }
    return make_object(cls);
}
