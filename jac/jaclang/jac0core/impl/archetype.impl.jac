"""Implementation for archetype constructs."""

"""Validate access."""
impl Access.check(anchor: str) -> (AccessLevel | None) {
    return self.anchors.get(anchor);
}

"""Serialize PermissionDenied into a JSON-safe dict for the response envelope."""
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

"""Render PermissionDenied as a single-line user-facing message."""
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

"""Filter edge."""
impl ObjectSpatialDestination.edge_filter(arch: Archetype) -> bool {
    return (not self.edge or self.edge(arch));
}

"""Filter node."""
impl ObjectSpatialDestination.node_filter(arch: Archetype) -> bool {
    return (not self.nd or self.nd(arch));
}

"""Override Init."""
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

"""Convert filter."""
impl ObjectSpatialPath.convert(
    filter: ObjectSpatialFilter
) -> (Callable[([Archetype], bool)] | None) {
    if not filter {
        return None;
    }
    if callable(filter) {
        return filter;
    } elif isinstance(filter, `list) {
        return lambda i: Any : (i in filter);
    }
    return lambda i: Any : (i == filter);
}

"""Append destination."""
impl ObjectSpatialPath.append(
    direction: EdgeDir, `edge: ObjectSpatialFilter, nd: ObjectSpatialFilter
) -> ObjectSpatialPath {
    self.destinations.append(
        ObjectSpatialDestination(direction, self.convert(`edge), self.convert(nd))
    );
    return self;
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_out(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.OUT, `edge, nd);
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_in(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.IN, `edge, nd);
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_any(
    `edge: ObjectSpatialFilter = None, nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.ANY, `edge, nd);
}

"""Set edge only."""
impl ObjectSpatialPath.set_edge_only -> ObjectSpatialPath {
    self.edge_only = True;
    return self;
}

"""Repr builder."""
impl ObjectSpatialPath.repr_builder(
    repr_str: str, dest: ObjectSpatialDestination, mark: str
) -> str {
    repr_str += mark;
    repr_str += f" (edge{' filter' if dest.edge else ''}) ";
    repr_str += mark;
    repr_str += f" (node{' filter' if dest.nd else ''}) ";
    return repr_str;
}

"""Override repr."""
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

"""Check if state."""
impl Anchor.is_populated -> bool {
    return ('archetype' in self.__dict__);
}

"""Return unsynced copy of anchor."""
impl Anchor.make_stub -> TANCH {
    if self.is_populated() {
        unloaded = object.__new__(self.__class__);
        unloaded.id = self.id;
        return unloaded;
    }
    return self;
}

"""Retrieve the Archetype from db and return."""
impl Anchor.populate -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    ctx = Jac.get_context();
    anchor = ctx.mem.get(self.id);
    if anchor {
        self.__dict__.update(anchor.__dict__);
    }
}

"""Trigger load if detects unloaded state."""
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

"""Serialize Anchor."""
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

"""Deserialize Anchor."""
impl Anchor.__setstate__(state: dict[(str, Any)]) -> None {
    self.__dict__.update(state);
    if (self.is_populated() and self.archetype) {
        self.archetype.__jac__ = self;
        self.hash = hash(dumps(self));
    }
    # Snapshot initial edge IDs for merge-based conflict resolution
    if isinstance(self, NodeAnchor) {
        self.__dict__['_initial_edge_ids'] = frozenset(
            e.id for e in self.__dict__.get('edges', [])
        );
    }
}

"""Override representation."""
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

"""Report Anchor."""
impl Anchor.`report -> AnchorReport {
    return AnchorReport(
        id=self.id.hex,
        context=asdict(self.archetype)
            if (is_dataclass(self.archetype) and not isinstance(self.archetype, `type))
            else {}
    );
}

"""Override hash for anchor."""
impl Anchor.__hash__ -> int {
    return hash(self.id);
}

"""Override equal implementation."""
impl Anchor.__eq__(other: object) -> bool {
    if isinstance(other, Anchor) {
        return ((self.__class__ is other.__class__) and (self.id == other.id));
    }
    return False;
}

"""Check if node anchor is fully populated (has edges)."""
impl NodeAnchor.is_populated -> bool {
    d = self.__dict__;
    return 'edges' in d and 'archetype' in d;
}

"""Check if edge anchor is fully populated (has source/target)."""
impl EdgeAnchor.is_populated -> bool {
    d = self.__dict__;
    return 'source' in d and 'target' in d and 'archetype' in d;
}

"""Serialize Node Anchor."""
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

"""Compute edge delta (added, removed) since this node was loaded from DB.
Returns None if no snapshot exists (newly created node)."""
impl NodeAnchor.edge_delta -> (tuple[(set[UUID], set[UUID])] | None) {
    initial_fs: (frozenset | None) = self.__dict__.get('_initial_edge_ids');
    if initial_fs is None {
        return None;
    }
    initial: set[UUID] = set(initial_fs);
    current: set[UUID] = set(e.id for e in self.edges);
    return (current - initial, initial - current);
}

"""Get decoded topology index (lazy-decoded from blob)."""
impl NodeAnchor.get_topology_index -> Any {
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    if self.topology_index_data {
        return TopologyIndex.decode(self.topology_index_data);
    }
    return TopologyIndex();
}

"""Set topology index from TopologyIndex object (encodes to blob)."""
impl NodeAnchor.set_topology_index(index: Any) -> None {
    self.topology_index_data = index.encode();
}

"""Serialize Edge Anchor."""
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

"""Create default anchor."""
@cached_property
impl Archetype.__jac__ -> Anchor {
    return Anchor(archetype=self);
}

"""Configure subclasses."""
impl Archetype.__init_subclass__(cls: Any, **kwargs: object) -> None {
    super.__init_subclass__(**kwargs);
    if not cls.__dict__.get('__jac_base__', False) {
        import from jaclang { JacRuntimeInterface as _ }
        _.make_archetype(cls);
        for hook in Archetype._subclass_hooks {
            hook(cls);
        }
    }
}

"""Set attribute on archetype and track dirty fields after initialization."""
impl Archetype.__setattr__(name: str, value: Any) -> None {
    object.__setattr__(self, name, value);
    if self.__dict__.get('__jac_initialized__', False) and not name.startswith('_') {
        dirty: set[str] = self.__dict__.get('__jac_dirty_fields__');
        if not isinstance(dirty, set) {
            dirty = set();
            object.__setattr__(self, '__jac_dirty_fields__', dirty);
        }
        dirty.add(name);
    }
}

"""Mark archetype as initialized so subsequent field changes are tracked as dirty."""
impl Archetype.postinit -> None {
    object.__setattr__(self, '__jac_initialized__', True);
}

"""Override repr for archetype."""
impl Archetype.__repr__ -> str {
    return f"{self.__class__.__name__}";
}

"""Override access validation."""
impl Archetype.__jac_access__ -> (AccessLevel | str | int | None) {
    return None;
}

"""Override repr for archetype."""
impl GenericEdge.__repr__ -> str {
    return f"{self.__class__.__name__}()";
}

"""Create default anchor."""
@cached_property
impl Root.__jac__ -> NodeAnchor {
    return NodeAnchor(archetype=self, persistent=True, edges=[]);
}

"""Override repr for archetype."""
impl Root.__repr__ -> str {
    return f"{self.__class__.__name__}()";
}

"""Get function parameter annotations."""
@cached_property
impl ObjectSpatialFunction.trigger -> (
    type | UnionType | tuple[((type | UnionType), ...)] | None
) {
    parameters = signature(self.func, eval_str=True).parameters;
    if (len(parameters) >= 2) {
        second_param = `list(parameters.values())[1];
        ty = second_param.annotation;
        return ty if (ty != _empty) else None;
    }
    return None;
}
