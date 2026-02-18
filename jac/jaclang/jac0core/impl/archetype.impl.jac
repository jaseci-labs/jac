"""Implementation for archetype constructs."""

"""Validate access."""
impl Access.check(self: Access, anchor: str) -> (AccessLevel | None) {
    return self.anchors.get(anchor);
}

"""Filter edge."""
impl ObjectSpatialDestination.edge_filter(
    self: ObjectSpatialDestination, arch: Archetype
) -> bool {
    return (not self.edge or self.edge(arch));
}

"""Filter node."""
impl ObjectSpatialDestination.node_filter(
    self: ObjectSpatialDestination, arch: Archetype
) -> bool {
    return (not self.nd or self.nd(arch));
}

"""Override Init."""
impl ObjectSpatialPath.init(
    self: ObjectSpatialPath,
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
    self: ObjectSpatialPath, filter: ObjectSpatialFilter
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
    self: ObjectSpatialPath,
    direction: EdgeDir,
    `edge: ObjectSpatialFilter,
    nd: ObjectSpatialFilter
) -> ObjectSpatialPath {
    self.destinations.append(
        ObjectSpatialDestination(direction, self.convert(`edge), self.convert(nd))
    );
    return self;
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_out(
    self: ObjectSpatialPath,
    `edge: ObjectSpatialFilter = None,
    nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.OUT, `edge, nd);
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_in(
    self: ObjectSpatialPath,
    `edge: ObjectSpatialFilter = None,
    nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.IN, `edge, nd);
}

"""Override greater than function."""
impl ObjectSpatialPath.edge_any(
    self: ObjectSpatialPath,
    `edge: ObjectSpatialFilter = None,
    nd: ObjectSpatialFilter = None
) -> ObjectSpatialPath {
    return self.append(EdgeDir.ANY, `edge, nd);
}

"""Set edge only."""
impl ObjectSpatialPath.set_edge_only(self: ObjectSpatialPath) -> ObjectSpatialPath {
    self.edge_only = True;
    return self;
}

"""Repr builder."""
impl ObjectSpatialPath.repr_builder(
    self: ObjectSpatialPath, repr_str: str, dest: ObjectSpatialDestination, mark: str
) -> str {
    repr_str += mark;
    repr_str += f" (edge{' filter' if dest.edge else ''}) ";
    repr_str += mark;
    repr_str += f" (node{' filter' if dest.nd else ''}) ";
    return repr_str;
}

"""Override repr."""
impl ObjectSpatialPath.__repr__(self: ObjectSpatialPath) -> str {
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
impl Anchor.is_populated(self: Anchor) -> bool {
    return ('archetype' in self.__dict__);
}

"""Return unsynced copy of anchor."""
impl Anchor.make_stub(self: Anchor) -> TANCH {
    if self.is_populated() {
        unloaded = object.__new__(self.__class__);
        unloaded.id = self.id;
        return unloaded;
    }
    return self;
}

"""Retrieve the Archetype from db and return."""
impl Anchor.populate(self: Anchor) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    ctx = Jac.get_context();
    anchor = ctx.mem.get(self.id);
    if anchor {
        self.__dict__.update(anchor.__dict__);
    }
}

"""Trigger load if detects unloaded state."""
impl Anchor.__getattr__(self: Anchor, name: str) -> object {
    if not self.is_populated() {
        self.populate();
        if not self.is_populated() {
            raise ValueError(
                f"{self.__class__.__name__} [{self.id}] is not a validreference!"
            ) ;
        }
        return getattr(self, name);
    }
    raise AttributeError(
        f"'{self.__class__.__name__} object has not attribute {name}'"
    ) ;
}

"""Serialize Anchor."""
impl Anchor.__getstate__(self: Anchor) -> dict[(str, Any)] {
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
impl Anchor.__setstate__(self: Anchor, state: dict[(str, Any)]) -> None {
    self.__dict__.update(state);
    if (self.is_populated() and self.archetype) {
        self.archetype.__jac__ = self;
        self.hash = hash(dumps(self));
    }
}

"""Override representation."""
impl Anchor.__repr__(self: Anchor) -> str {
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
impl Anchor.`report(self: Anchor) -> AnchorReport {
    return AnchorReport(
        id=self.id.hex,
        context=asdict(self.archetype)
        if (is_dataclass(self.archetype) and not isinstance(self.archetype, `type))
        else {}
    );
}

"""Override hash for anchor."""
impl Anchor.__hash__(self: Anchor) -> int {
    return hash(self.id);
}

"""Override equal implementation."""
impl Anchor.__eq__(self: Anchor, other: object) -> bool {
    if isinstance(other, Anchor) {
        return ((self.__class__ is other.__class__) and (self.id == other.id));
    }
    return False;
}

"""Serialize Node Anchor."""
impl NodeAnchor.__getstate__(self: NodeAnchor) -> dict[(str, object)] {
    state = super.__getstate__();
    if self.is_populated() {
        state['edges'] = [`edge.make_stub() for `edge in self.edges];
    }
    return state;
}

"""Serialize Edge Anchor."""
impl EdgeAnchor.__getstate__(self: EdgeAnchor) -> dict[(str, object)] {
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
@ cached_property
impl Archetype.__jac__(self: Archetype) -> Anchor {
    return Anchor(archetype=self);
}

"""Configure subclasses."""
impl Archetype.__init_subclass__(cls: Any, **kwargs: object) -> None {
    super.__init_subclass__(**kwargs);
    if not cls.__dict__.get('__jac_base__', False) {
        import from jaclang { JacRuntimeInterface as _ }
        _.make_archetype(cls);
    }
}

"""Override repr for archetype."""
impl Archetype.__repr__(self: Archetype) -> str {
    return f"{self.__class__.__name__}";
}

"""Override access validation."""
impl Archetype.__jac_access__(self: Archetype) -> (AccessLevel | str | int | None) {
    return None;
}

"""Override repr for archetype."""
impl GenericEdge.__repr__(self: GenericEdge) -> str {
    return f"{self.__class__.__name__}()";
}

"""Create default anchor."""
@ cached_property
impl Root.__jac__(self: Root) -> NodeAnchor {
    return NodeAnchor(archetype=self, persistent=True, edges=[]);
}

"""Override repr for archetype."""
impl Root.__repr__(self: Root) -> str {
    return f"{self.__class__.__name__}()";
}

"""Get function parameter annotations."""
@ cached_property
impl ObjectSpatialFunction.trigger(
    self: ObjectSpatialFunction
) -> (type | UnionType | tuple[((type | UnionType), ...)] | None) {
    parameters = signature(self.func, eval_str=True).parameters;
    if (len(parameters) >= 2) {
        second_param = `list(parameters.values())[1];
        ty = second_param.annotation;
        return ty if (ty != _empty) else None;
    }
    return None;
}
