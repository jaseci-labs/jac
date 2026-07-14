impl Access.check(anchor: str) -> (AccessLevel | None) {
    return self.anchors.get(anchor);
}

impl PermissionDenied.to_dict -> dict[(str, Any)] {
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
        f"Hint: at the owner-side call `grant(node, level={self.required.name})`, "
        f"or expose an ability on the target node and route writes through it."
    );
}

impl ObjectSpatialDestination.edge_filter(arch: Archetype) -> bool {
    return (not self.edge or self.edge(arch));
}

impl ObjectSpatialDestination.node_filter(arch: Archetype) -> bool {
    return (not self.nd or self.nd(arch));
}

impl ObjectSpatialPath.init(
    origin: (NodeArchetype | list[NodeArchetype]),
    destinations: (list[ObjectSpatialDestination] | None) = None
) -> None {
    if not isinstance(origin, `list) {
        origin = [origin];
    }
    self.origin = origin;
    self.destinations = [] if (destinations is None) else destinations;
    self.edge_only = False;
    self.from_visit = False;
}

impl ObjectSpatialPath.convert(
    filter: ObjectSpatialFilter
) -> (Callable[([Archetype], bool)] | None) {
    if not filter {
        return None;
    }
    if callable(filter) {
        return filter;
    } elif isinstance(filter, `list) {
        return lambda (i: any) { i in filter; };
    }
    return lambda (i: any) { i == filter; };
}

impl ObjectSpatialPath.append(
    direction: EdgeDir, `edge: ObjectSpatialFilter, nd: ObjectSpatialFilter
) -> ObjectSpatialPath {
    self.destinations.append(
        ObjectSpatialDestination(direction, self.convert(`edge), self.convert(nd))
    );
    return self;
}

impl ObjectSpatialPath.edge_out(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.OUT, `edge, nd);
}

impl ObjectSpatialPath.edge_in(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.IN, `edge, nd);
}

impl ObjectSpatialPath.edge_any(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.ANY, `edge, nd);
}

impl ObjectSpatialPath.repr_builder(
    repr_str: str, dest: ObjectSpatialDestination, mark: str
) -> str {
    repr_str += mark;
    repr_str += f" (edge{' filter' if dest.edge else ''}) ";
    repr_str += mark;
    repr_str += f" (node{' filter' if dest.nd else ''}) ";
    return repr_str;
}

impl ObjectSpatialPath.__repr__ -> str {
    repr_str = 'nodes ';
    for dest in self.destinations {
        if (dest.direction == EdgeDir.IN) {
            repr_str = self.repr_builder(repr_str, dest, '<<');
        } elif (dest.direction == EdgeDir.OUT) {
            repr_str = self.repr_builder(repr_str, dest, '>>');
        } else {
            repr_str = self.repr_builder(repr_str, dest, '--');
        }
    }
    return repr_str.strip();
}

impl Anchor.is_populated -> bool {
    return ('archetype' in self.__dict__);
}

impl Anchor.make_stub -> TANCH {
    if self.is_populated() {
        unloaded = object.__new__(self.__class__);
        unloaded.id = self.id;
        return unloaded;
    }
    return self;
}

impl Anchor.populate -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    ctx = Jac.get_context();
    anchor = ctx.mem.get(self.id);
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

impl Anchor.__getstate__ -> dict[(str, Any)] {
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

impl Anchor.__setstate__(state: dict[(str, Any)]) -> None {
    self.__dict__.update(state);
    if (self.is_populated() and self.archetype) {
        self.archetype.__jac__ = self;
        self.hash = hash(dumps(self));
    }

    if isinstance(self, NodeAnchor) {
        self.__dict__['_initial_edge_ids'] = frozenset(
            e.id for e in self.__dict__.get('edges', [])
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
        id=self.id.hex,
        context=asdict(self.archetype)
            if (is_dataclass(self.archetype) and not isinstance(self.archetype, `type))
            else {}
    );
}

impl Anchor.__hash__ -> int {
    return hash(self.id);
}

impl Anchor.__eq__(other: object) -> bool {
    if isinstance(other, Anchor) {
        return ((self.__class__ is other.__class__) and (self.id == other.id));
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
        state['edges'] = [`edge.make_stub() for `edge in self.edges];
        if self.topology_index_data is not None {
            state['topology_index_data'] = self.topology_index_data;
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
    current: set[UUID] = set(e.id for e in self.edges);
    return (current - initial, initial - current);
}

impl NodeAnchor.get_topology_index -> any {
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    if self.topology_index_data {
        return TopologyIndex.decode(self.topology_index_data);
    }
    return TopologyIndex();
}

impl NodeAnchor.set_topology_index(index: any) -> None {
    self.topology_index_data = index.encode();
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
        if (ed.id == `edge.id) {
            self.edges.pop(idx);
            break;
        }
    }
}

impl EdgeAnchor.detach -> None {
    self.source.remove_edge(self);
    self.target.remove_edge(self);
}

@cached_property
impl Archetype.__jac__ -> Anchor {
    return Anchor(archetype=self);
}

impl Archetype.__init_subclass__(cls: any, **kwargs: object) -> None {
    super.__init_subclass__(**kwargs);
    if not cls.__dict__.get('__jac_base__', False) {
        import from jaclang { JacRuntimeInterface as _ }
        _.make_archetype(cls);
        for hook in Archetype._subclass_hooks {
            hook(cls);
        }
    }
}

impl Archetype.postinit -> None { }

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
    return NodeAnchor(archetype=self, persistent=True, edges=[]);
}

impl Root.__getattr__(name: str) -> Root {
    if name == 'shared' {
        import from jaclang.jac0core.runtime { JacRuntime }
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
