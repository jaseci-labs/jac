impl Access.check(anchor: str) -> (AccessLevel | None) {
    return self.anchors.get(anchor);
}

impl PermissionDenied.to_dict -> dict[(str, any)] {
    return {
        "operation": self.operation,
        "target_id": self.target_id,
        "target_type": self.target_type,
        "target_owner": self.target_owner,
        "required": self.required.name,
        "actual": self.actual.name,
        "message": self.message()
    };
}

impl PermissionDenied.message -> str {
    owner = self.target_owner or "<system>";
    return (
        f"Permission denied: {self.operation} on "
        f"{self.target_type}[{self.target_id}] owned by root[{owner}]; "
        f"required {self.required.name}, have {self.actual.name}. "
        f"Hint: at the owner-side call "
        f"`Jac.allow_root(node, root_id, AccessLevel.{self.required.name})` to "
        f"share with one user's root, `grant(node, "
        f"level=AccessLevel.{self.required.name})` to open the node to every "
        f"user, or expose an ability on the target node and route writes "
        f"through it."
    );
}

impl Anchor.ensure_id -> UUID {
    aid = self.id;
    if aid is None {
        aid = uuid4();
        self.id = aid;
    }
    return aid;
}

impl Anchor.own_access -> Permission {
    perm = self.access;
    if perm is None {
        perm = Permission();
        self.access = perm;
    }
    return perm;
}

impl Anchor.is_populated -> bool {
    return ('archetype' in self.__dict__);
}

impl Anchor.make_stub -> TANCH {
    if self.is_populated() {
        unloaded = object.__new__(self.__class__);
        unloaded.id = self.ensure_id();
        return unloaded;
    }
    return self;
}

impl Anchor.populate -> None {
    aid = self.id;
    if aid is None {
        return;
    }
    import from jaclang { JacRuntimeInterface as Jac }
    ctx = Jac.get_context();
    anchor = ctx.mem.get(aid);
    if anchor {
        self.__dict__.update(anchor.__dict__);
    }
}

impl Anchor.__getattr__(name: str) -> object {
    if not self.is_populated() {
        self.populate();
        if not self.is_populated() {
            raise ValueError(
                f"{self.__class__.__name__} [{self.id}] is not a validreference!"
            );
        }
        return getattr(self, name);
    }
    raise AttributeError(
        f"'{self.__class__.__name__} object has not attribute {name}'"
    );
}

impl Anchor.__getstate__ -> dict[(str, any)] {
    if self.is_populated() {
        unlinked = object.__new__(untracked_class(self.archetype.__class__));
        unlinked.__dict__.update(self.archetype.__dict__);
        unlinked.__dict__.pop('__jac__', None);
        return {
            'id': self.ensure_id(),
            'archetype': unlinked,
            'root': self.root,
            'access': self.access,
            'persistent': self.persistent
        };
    }
    return {'id': self.ensure_id()};
}

impl Anchor.__setstate__(state: dict[(str, any)]) -> None {
    persistent = bool(state.pop('persistent', False));
    self.__dict__.update(state);
    self.__dict__.setdefault('destroyed', False);
    self.persistent = persistent;
    if (self.is_populated() and self.archetype) {
        self.archetype.__jac__ = self;
        self.hash = hash(dumps(self));
    }

    if isinstance(self, NodeAnchor) {
        self.__dict__['_initial_edge_ids'] = frozenset(
            e.ensure_id() for e in self.__dict__.get('edges', [])
        );
    }
}

impl Anchor.__repr__ -> str {
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

impl Anchor.`report -> AnchorReport {
    return AnchorReport(
        id=self.ensure_id().hex,
        context=asdict(self.archetype)
            if (is_jac_object(self.archetype) and not isinstance(self.archetype, `type))
            else {}
    );
}

impl Anchor.__hash__ -> int {
    aid = self.id;
    return hash(aid) if aid is not None else id(self);
}

impl Anchor.__eq__(other: object) -> bool {
    if self is other {
        return True;
    }
    if isinstance(other, Anchor) and (self.__class__ is other.__class__) {
        aid = self.id;
        return aid is not None and aid == other.id;
    }
    return False;
}

impl NodeAnchor.is_populated -> bool {
    d = self.__dict__;
    return ('edges' in d or '_edge_loader' in d) and 'archetype' in d;
}

impl NodeAnchor.__getattr__(name: str) -> object {
    if name == 'edges' {
        loader = self.__dict__.get('_edge_loader');
        if loader is not None {
            edges = loader();
            self.__dict__['edges'] = edges;
            self.__dict__.pop('_edge_loader', None);
            return edges;
        }
    }
    return super.__getattr__(name);
}

impl NodeAnchor.loaded_edges -> list[EdgeAnchor] {
    return self.__dict__.get('edges') or [];
}

impl EdgeAnchor.is_populated -> bool {
    d = self.__dict__;
    return 'source' in d and 'target' in d and 'archetype' in d;
}

impl NodeAnchor.__getstate__ -> dict[(str, object)] {
    state = super.__getstate__();
    if self.is_populated() {
        if self.persistent {
            state['edges'] = [`edge.make_stub() for `edge in self.all_edges()];
        } else {
            state['edges'] = `list(self.edges);
            state['out_light'] = self.out_light;
            state['in_light'] = self.in_light;
        }
    }
    return state;
}

impl NodeAnchor.edge_delta -> (tuple[(set[UUID], set[UUID])] | None) {
    initial_fs: (frozenset | None) = self.__dict__.get('_initial_edge_ids');
    if initial_fs is None {
        return None;
    }
    initial: set[UUID] = set(initial_fs);
    current: set[UUID] = set(e.ensure_id() for e in self.all_edges());
    return (current - initial, initial - current);
}

impl EdgeAnchor.__getstate__ -> dict[(str, object)] {
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

impl NodeAnchor.remove_edge(`edge: EdgeAnchor) -> None {
    for (idx, ed) in enumerate(self.edges) {
        if same_anchor(ed, `edge) {
            self.edges.pop(idx);
            break;
        }
    }
}

impl EdgeAnchor.detach -> None {
    if self.light {
        light_disconnect(self.source, `type(self.archetype), self.target);
        return;
    }
    self.source.remove_edge(self);
    self.target.remove_edge(self);
    import from jaclang.runtime.osp_graph_sv { sv_forget_edge }
    sv_forget_edge(self);

    import from jaclang.runtime.runtime { JacRuntime }
    ctx = JacRuntime.peek_context();
    aid = self.id;
    if ctx is not None and aid is not None {
        ctx.mem.delete(aid);
    }
}

@cached_property
impl Archetype.__jac__ -> Anchor {
    return Anchor(archetype=self);
}

impl Archetype.__init_subclass__(cls: any, **kwargs: object) -> None {
    super.__init_subclass__(**kwargs);
    _edge_subtypes.clear();
    if not cls.__dict__.get('__jac_base__', False) {
        import from jaclang { JacRuntimeInterface as _ }
        _.make_archetype(cls);
        if 'drop' in cls.__dict__ {
            import from jaclang.runtime.region { is_drop_hook }
            if is_drop_hook(cls.__dict__['drop']) {
                import from jaclang.runtime.builtin { _jac_region_instrument }
                _jac_region_instrument(cls);
            }
        }
        for hook in Archetype._subclass_hooks {
            hook(cls);
        }
    }
}

impl Archetype._subclass_tree -> list[type] {
    found: list[type] = [];
    seen: set[type] = set();
    pending: list[type] = list(Archetype.__subclasses__());
    while pending {
        cls = pending.pop();
        if cls in seen {
            continue;
        }
        seen.add(cls);
        pending.extend(cls.__subclasses__());
        if not cls.__dict__.get('__jac_base__', False) {
            found.append(cls);
        }
    }
    return found;
}

impl Archetype.install_subclass_hook(hook: Callable[[type], None]) -> None {
    with _subclass_hook_lock {
        if `any(installed is hook for installed in Archetype._subclass_hooks) {
            return;
        }
        Archetype._subclass_hooks = Archetype._subclass_hooks + (hook, );
    }
    for cls in Archetype._subclass_tree() {
        try {
            hook(cls);
        } except Exception as e {
            logger.warning(
                f"archetype subclass hook back-fill failed for "
                f"{cls.__module__}.{cls.__name__}: {e}"
            );
        }
    }
}

impl Archetype.uninstall_subclass_hook(hook: Callable[[type], None]) -> None {
    with _subclass_hook_lock {
        Archetype._subclass_hooks = tuple(
            installed
            for installed in Archetype._subclass_hooks
            if installed is not hook
        );
    }
}

impl Archetype.postinit -> None {}

impl Archetype.__repr__ -> str {
    return f"{self.__class__.__name__}";
}

impl Archetype.__jac_access__ -> (AccessLevel | str | int | None) {
    return None;
}

impl GenericEdge.__repr__ -> str {
    return f"{self.__class__.__name__}()";
}

@cached_property
impl Root.__jac__ -> NodeAnchor {
    anchor = NodeAnchor(archetype=self, edges=[]);
    anchor.persistent = True;
    anchor.ensure_id();
    return anchor;
}

impl Root.__getattr__(name: str) -> Root {
    if name == 'shared' {
        import from jaclang.runtime.runtime { JacRuntime }
        import from typing { cast }
        return cast(Root, JacRuntime.get_shared_root());
    }
    raise AttributeError(f"'{type(self).__name__}' object has no attribute '{name}'");
}

impl Root.__repr__ -> str {
    return f"{self.__class__.__name__}()";
}

@cached_property
impl ObjectSpatialFunction.trigger -> (
    type | UnionType | tuple[((type | UnionType), ...)] | None
) {
    if self.trigger_override is not _NO_TRIGGER {
        ty = self.trigger_override();
    } else {
        parameters = signature(self.func, eval_str=True).parameters;
        if len(parameters) < 2 {
            return None;
        }
        second_param = `list(parameters.values())[1];
        ty = second_param.annotation;
        if ty == _empty {
            return None;
        }
    }

    if isinstance(ty, Archetype) {
        raise TypeError(
            f"Ability trigger must be a class, not an instance of `{type(
                ty
            ).__name__}`. "
            f"Use `with {type(ty).__name__} entry` instead."
        );
    }
    return ty;
}

impl NodeAnchor.all_edges -> list[EdgeAnchor] {
    out = self.out_light;
    inn = self.in_light;
    if out is None and inn is None {
        return self.edges;
    }
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    me = self.archetype;
    if out is not None {
        self.out_light = None;
        for (cls, lst) in out.items() {
            for other in lst {
                oa = other.__jac__;
                _drop_back(oa.in_light, cls, me);
                JacRuntimeInterface.heavy_edge(self, oa, cls, False, None);
            }
        }
    }
    if inn is not None {
        self.in_light = None;
        for (cls, lst) in inn.items() {
            for other in _deref(lst) {
                oa = other.__jac__;
                _drop_entry(oa.out_light, cls, me);
                JacRuntimeInterface.heavy_edge(oa, self, cls, False, None);
            }
        }
    }
    return self.edges;
}

impl NodeAnchor.detach_light -> None {
    out = self.out_light;
    if out is not None {
        for cls in `list(out.keys()) {
            light_clear(self, cls, True);
        }
        self.out_light = None;
    }
    inn = self.in_light;
    if inn is not None {
        for cls in `list(inn.keys()) {
            light_clear(self, cls, False);
        }
        self.in_light = None;
    }
}

impl Anchor.persistent.getter -> bool {
    return self._persistent;
}

impl Anchor.persistent.setter(persistent: bool) -> None {
    self._persistent = persistent;

    if persistent and 'archetype' in self.__dict__ {
        track_writes(self.archetype);
    }
}

impl NodeAnchor.has_heavy_edges -> bool {
    return bool(self.edges);
}

impl access_level_cast(val: int | str | AccessLevel) -> AccessLevel {
    if isinstance(val, AccessLevel) {
        return val;
    }
    if isinstance(val, str) {
        val = val.upper();
    }
    _map: dict[int | str, AccessLevel] = {
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

impl PermissionDenied.__eq__(other: object) -> bool {
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

impl same_anchor(a: (Anchor | None), b: (Anchor | None)) -> bool {
    if a is b {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    aid = a.id;
    return aid is not None and aid == b.id;
}

impl anchor_key(anchor: Anchor) -> any {
    aid = anchor.id;
    return aid if aid is not None else id(anchor);
}

impl NodeArchetype.__jac__(self: NodeArchetype) -> NodeAnchor {
    return NodeAnchor(archetype=self, edges=[]);
}

impl EdgeArchetype.__eq__(other: object) -> bool {
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

impl EdgeArchetype.__hash__ -> int {
    mine = self.__dict__.get('__jac__');
    if mine is not None and mine.light {
        return hash((`type(self), id(mine.source), id(mine.target)));
    }
    return id(self);
}

impl WalkerArchetype.__jac__(self: WalkerArchetype) -> WalkerAnchor {
    return WalkerAnchor(archetype=self);
}

impl ObjectArchetype.__jac__(self: ObjectArchetype) -> ObjectAnchor {
    return ObjectAnchor(archetype=self);
}

impl is_light_edge_type(cls: type) -> bool {
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

impl edge_ctor_args(cls: type) -> tuple[str, ...] {
    known = _edge_ctor_args.get(cls);
    if known is not None {
        return known;
    }
    names: list[str] = [];
    try {
        for param in signature(cls).parameters.values() {
            if param.default is _empty
                and param.kind
                    in (Parameter.POSITIONAL_OR_KEYWORD, Parameter.KEYWORD_ONLY) {
                names.append(param.name);
            }
        }
    } except (TypeError, ValueError) {
        names = [];
    }
    result = tuple(names);
    _edge_ctor_args[cls] = result;
    return result;
}

impl new_connect_edge(
    ct: (type[EdgeArchetype] | EdgeArchetype),
    conn_assign: (tuple[(tuple[any, ...], tuple[any, ...])] | None)
) -> tuple[EdgeArchetype, tuple[str, ...]] {
    if not isinstance(ct, `type) {
        return (ct, ());
    }
    if conn_assign {
        required = edge_ctor_args(ct);
        if required {
            given = dict(zip(conn_assign[0], conn_assign[1], strict=False));
            if all(name in given for name in required) {
                return (ct(**{name: given[name] for name in required}), required);
            }
        }
    }
    return (ct(), ());
}

impl edge_subtypes(cls: type) -> tuple[type, ...] {
    known = _edge_subtypes.get(cls);
    if known is not None {
        return known;
    }
    out: list[type] = [cls];
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

impl _as_refs(held: any) -> any {
    return [held] if isinstance(held, weakref.ref) else held;
}

impl _deref(lst: any) -> list[any] {
    if isinstance(lst, weakref.ref) {
        one = lst();
        return [one] if one is not None else [];
    }
    out: list[any] = [];
    for r in lst {
        a = r();
        if a is not None {
            out.append(a);
        }
    }
    return out;
}

impl _InLinks.init(self: _InLinks, refs: list[any]) {
    super.init();
    self._rebuild(refs);
}

impl _InLinks._rebuild(self: _InLinks, refs: list[any]) {
    list.clear(self);
    self.at = {};
    for r in refs {
        src = r();
        if src is not None {
            self.at.setdefault(id(src), []).append(len(self));
        }
        list.append(self, r);
    }
    self.live = len(self);
    self.limit = max(_INDEX_AT, 2 * len(self));
}

impl _InLinks.add(self: _InLinks, src: NodeArchetype) {
    self.at.setdefault(id(src), []).append(len(self));
    list.append(self, weakref.ref(src));
    self.live += 1;
    if len(self) >= self.limit {
        self._rebuild(
            [
                r
                for r in self
                if r() is not None
            ]
        );
    }
}

impl _InLinks.drop(self: _InLinks, src: NodeArchetype) -> bool {
    slots = self.at.get(id(src));
    while slots {
        i = slots.pop(0);
        if self[i]() is src {
            self[i] = _VACANT;
            self.live -= 1;
            if not slots {
                self.at.pop(id(src), None);
            }
            return True;
        }
    }
    self.at.pop(id(src), None);
    return False;
}

impl _connect_back(inn: dict[type, any], cls: type, src: NodeArchetype) {
    lst = inn.get(cls);
    if lst is None {
        inn[cls] = weakref.ref(src);
    } elif isinstance(lst, weakref.ref) {
        inn[cls] = [lst, weakref.ref(src)];
    } elif isinstance(lst, _InLinks) {
        lst.add(src);
    } elif len(lst) + 1 < _INDEX_AT {
        lst.append(weakref.ref(src));
    } else {
        indexed = _InLinks(lst);
        indexed.add(src);
        inn[cls] = indexed;
    }
}

impl _drop_back(d: (dict[type, any] | None), cls: type, src: NodeArchetype) -> bool {
    if d is None {
        return False;
    }
    lst = d.get(cls);
    if lst is None {
        return False;
    }
    if isinstance(lst, weakref.ref) {
        if lst() is not src {
            return False;
        }
        d.pop(cls, None);
        return True;
    }
    if isinstance(lst, _InLinks) {
        if not lst.drop(src) {
            return False;
        }
        if lst.live == 0 {
            d.pop(cls, None);
        }
        return True;
    }
    for (i, r) in enumerate(lst) {
        if r() is src {
            lst.pop(i);
            if not lst {
                d.pop(cls, None);
            }
            return True;
        }
    }
    return False;
}

impl light_connect(src: NodeAnchor, cls: type, tgt: NodeAnchor) {
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
    _connect_back(inn, cls, src.archetype);
}

impl _drop_entry(d: (dict[type, list[any]] | None), cls: type, key: any) -> bool {
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

impl light_disconnect(src: NodeAnchor, cls: type, tgt: NodeAnchor) -> bool {
    held = _drop_entry(src.out_light, cls, tgt.archetype);
    _drop_back(tgt.in_light, cls, src.archetype);
    return held;
}

impl light_clear(anchor: NodeAnchor, cls: type, outgoing: bool = True) -> bool {
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
        for other in lst {
            _drop_back(other.__jac__.in_light, cls, me);
        }
    } else {
        for other in _deref(lst) {
            _drop_entry(other.__jac__.out_light, cls, me);
        }
    }
    return True;
}

impl light_clear_matching(
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

impl _collect_light(d: dict[type, list[any]], cls: (type | None)) -> list[any] {
    if cls is None {
        out: list[any] = [];
        for lst in d.values() {
            out.extend(_as_refs(lst));
        }
        return out;
    }
    subs = edge_subtypes(cls);
    if len(subs) == 1 {
        lst = d.get(cls);
        return _as_refs(lst) if lst is not None else [];
    }
    found: list[any] = [];
    if len(subs) <= len(d) {
        for sub in subs {
            lst = d.get(sub);
            if lst {
                found.extend(_as_refs(lst));
            }
        }
    } else {
        for (k, lst) in d.items() {
            if lst and issubclass(k, cls) {
                found.extend(_as_refs(lst));
            }
        }
    }
    return found;
}

impl light_out(anchor: NodeAnchor, cls: (type | None)) -> list[any] {
    d = anchor.out_light;
    return _collect_light(d, cls) if d else [];
}

impl light_in(anchor: NodeAnchor, cls: (type | None)) -> list[any] {
    d = anchor.in_light;
    return _deref(_collect_light(d, cls)) if d else [];
}

impl light_hop(
    anchor: NodeAnchor, dir: int, cls: (type | None), edges_only: bool
) -> list[any] {
    if edges_only {
        out: list[any] = [];
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
        found: list[any] = [];
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

impl light_hop_answers(anchor: NodeAnchor, cls: (type | None)) -> bool {
    if anchor.persistent {
        return False;
    }
    if not anchor.has_heavy_edges() {
        return True;
    }
    return cls is not None and not anchor.mixed and is_light_edge_type(cls);
}

impl light_clear_hop(anchor: NodeAnchor, dir: int, cls: (type | None)) -> bool {
    hit = False;
    if dir != 1 and light_clear_matching(anchor, cls, True) {
        hit = True;
    }
    if dir != 2 and light_clear_matching(anchor, cls, False) {
        hit = True;
    }
    return hit;
}

impl light_edge_view(
    cls: type[EdgeArchetype], src: NodeAnchor, tgt: NodeAnchor
) -> EdgeArchetype {
    e = cls.__new__(cls);
    ea = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False);
    ea.light = True;
    e.__jac__ = ea;
    return e;
}

impl light_edge_views(
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

impl _note_write(an: any) {
    an.__dict__['_field_written'] = an.__dict__.get('_field_written', 0) + 1;
    an.__dict__.pop('_frozen', None);
}

impl _dirty_setattr(self: any, name: str, value: any) -> None {
    an = self.__dict__.get('__jac__');
    if an is None or not an.persistent {
        object.__setattr__(self, name, value);
        if an is not None {
            an.__dict__.pop('_frozen', None);
        }
        return;
    }
    import from jaclang.runtime.runtime { JacRuntime }
    ctx = JacRuntime.peek_context();
    if ctx is None {
        object.__setattr__(self, name, value);
        _note_write(an);
        return;
    }
    import from jaclang { JacRuntimeInterface }
    if not JacRuntimeInterface.check_write_access(an, op_hint="field_write") {
        return;
    }
    object.__setattr__(self, name, value);
    _note_write(an);
    md = ctx.mem?.mark_dirty;
    if md is not None {
        md(an);
    }
}

impl _dirty_delattr(self: any, name: str) -> None {
    an = self.__dict__.get('__jac__');
    if an is None or not an.persistent {
        object.__delattr__(self, name);
        if an is not None {
            an.__dict__.pop('_frozen', None);
        }
        return;
    }
    import from jaclang.runtime.runtime { JacRuntime }
    ctx = JacRuntime.peek_context();
    if ctx is None {
        object.__delattr__(self, name);
        _note_write(an);
        return;
    }
    import from jaclang { JacRuntimeInterface }
    if not JacRuntimeInterface.check_write_access(an, op_hint="field_write") {
        return;
    }
    object.__delattr__(self, name);
    _note_write(an);
    md = ctx.mem?.mark_dirty;
    if md is not None {
        md(an);
    }
}

impl untracked_class(cls: type[Archetype]) -> type[Archetype] {
    return cls.__dict__.get('__jac_untracked__', cls);
}

impl _untracked_new(cls: type[Archetype]) -> Archetype {
    return object.__new__(cls);
}

impl _tracked_reduce_ex(
    self: any, protocol: int
) -> tuple[Callable, tuple[type], dict[str, any]] {
    return (_untracked_new, (untracked_class(`type(self)), ), self.__dict__);
}

impl track_writes(arch: Archetype) -> None {
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
                '__delattr__': _dirty_delattr,
                '__reduce_ex__': _tracked_reduce_ex
            }
        );
        _tracked_classes[cls] = tracked;
    }
    object.__setattr__(arch, '__class__', tracked);
}
