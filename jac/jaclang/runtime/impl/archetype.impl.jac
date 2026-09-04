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
    } else {
        return {'id': self.ensure_id()};
    }
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
            if (is_dataclass(self.archetype) and not isinstance(self.archetype, `type))
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
    return 'edges' in d and 'archetype' in d;
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
    ctx = JacRuntime.exec_ctx;
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
            import from jaclang.runtime.builtin { _jac_region_instrument }
            _jac_region_instrument(cls);
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

impl Archetype.__jac_access_for__(caller: UUID) -> (AccessLevel | str | int | None) {
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
        back = weakref.ref(me);
        for (cls, lst) in out.items() {
            for other in lst {
                oa = other.__jac__;
                _drop_entry(oa.in_light, cls, back);
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
