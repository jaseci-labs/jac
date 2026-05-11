"""Topology utils implementation."""

"""Check if topology_index is enabled. The `JAC_TOPOLOGY_INDEX` env var
overrides the toml flag — useful for A/B benchmarking from a shell loop
without editing jac.toml. Recognized truthy values: 1 / true / yes / on
(case-insensitive); anything else is read as off."""
impl _is_enabled -> bool {
    import os;
    env = os.environ.get("JAC_TOPOLOGY_INDEX");
    if env is not None {
        return env.lower() in ("1", "true", "yes", "on");
    }
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        return cfg is not None and cfg.run.topology_index;
    } except Exception {
        return False;
    }
}

"""Get the root NodeAnchor that owns this anchor."""
impl _get_root_anchor(anchor: Any) -> Any {
    import from jaclang.jac0core.archetype { NodeAnchor as NA, Root }
    if anchor.root is None {
        # The anchor might BE the root node itself
        if isinstance(anchor, NA) and isinstance(anchor.archetype, Root) {
            return anchor;
        }
        return None;
    }
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        ctx = Jac.get_context();
        `root = ctx.mem.get(anchor.root);
        if isinstance(`root, NA) {
            return `root;
        }
    } except Exception {
        ;
    }
    return None;
}

"""Get the archetype class name."""
impl _type_name(`obj: object) -> str {
    return `type(`obj).__name__;
}

"""Get the user-defined MRO chain for an archetype instance, stopping at the
runtime base archetypes."""
impl _get_type_mro(`obj: object) -> list[str] {
    import from jaclang.jac0core.archetype {
        NodeArchetype,
        EdgeArchetype,
        WalkerArchetype,
        Archetype
    }
    stop_classes = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    chain: list[str] = [];
    for cls in `type(`obj).__mro__ {
        if cls in stop_classes {
            break;
        }
        chain.append(cls.__name__);
    }
    return chain;
}

"""Called after an edge is created between source and target."""
impl on_edge_created(source: Any, target: Any, `edge: Any) -> None {
    if not _is_enabled() {
        return;
    }
    if not source.persistent {
        return;
    }
    root_anchor = _get_root_anchor(source);
    if root_anchor is None {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        idx = TopologyIndex();
    }
    idx.add_node(
        root_anchor.id,
        _type_name(root_anchor.archetype),
        _get_type_mro(root_anchor.archetype)
    );
    idx.add_node(
        source.id,
        _type_name(source.archetype),
        _get_type_mro(source.archetype),
        None if source.root == root_anchor.id else source.root
    );
    target_owner = None;
    if target.root and target.root != root_anchor.id {
        target_owner = target.root;
    }
    idx.add_node(
        target.id,
        _type_name(target.archetype),
        _get_type_mro(target.archetype),
        target_owner
    );
    idx.add_edge(source.id, target.id, _type_name(`edge.archetype));
    if `edge.is_undirected {
        idx.add_edge(target.id, source.id, _type_name(`edge.archetype));
    }
    root_anchor.set_topology_index(idx);
}

"""Called when an edge is destroyed."""
impl on_edge_destroyed(source: Any, target: Any, `edge: Any) -> None {
    if not _is_enabled() {
        return;
    }
    if not source.persistent {
        return;
    }
    root_anchor = _get_root_anchor(source);
    if root_anchor is None {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        return;
    }
    idx.remove_edge(source.id, target.id, _type_name(`edge.archetype));
    if `edge.is_undirected {
        idx.remove_edge(target.id, source.id, _type_name(`edge.archetype));
    }
    root_anchor.set_topology_index(idx);
}

"""Called when a node is saved/persisted. Ensures it's in the root's index."""
impl on_node_saved(node_anchor: Any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent or node_anchor.root is None {
        return;
    }
    root_anchor = _get_root_anchor(node_anchor);
    if root_anchor is None {
        return;
    }
    # Don't recurse if we're saving the root itself with no edges yet
    if root_anchor.id == node_anchor.id {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        idx = TopologyIndex();
    }
    idx.add_node(
        root_anchor.id,
        _type_name(root_anchor.archetype),
        _get_type_mro(root_anchor.archetype)
    );
    idx.add_node(
        node_anchor.id,
        _type_name(node_anchor.archetype),
        _get_type_mro(node_anchor.archetype)
    );
    root_anchor.set_topology_index(idx);
}

"""Called when a node is destroyed."""
impl on_node_destroyed(node_anchor: Any) -> None {
    if not _is_enabled() {
        return;
    }
    if not node_anchor.persistent or node_anchor.root is None {
        return;
    }
    root_anchor = _get_root_anchor(node_anchor);
    if root_anchor is None {
        return;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) {
        return;
    }
    idx.remove_node(node_anchor.id);
    root_anchor.set_topology_index(idx);
}

"""Try to extract the type name from a filter lambda."""
impl _extract_type_name_from_filter(filt: (Callable | None)) -> (str | None) {
    if filt is None {
        return None;
    }
    # An Archetype instance acts as an identity filter (matches its own type).
    try {
        import from jaclang.jac0core.archetype { Archetype }
        if isinstance(filt, Archetype) {
            return `type(filt).__name__;
        }
    } except Exception {
        ;
    }
    try {
        closure = inspect.getclosurevars(filt);
        for val in `list(closure.nonlocals.values()) + `list(
            closure.globals.values()
        ) {
            if isinstance(val, `type) {
                import from jaclang.jac0core.archetype { Archetype as Arch }
                if issubclass(val, Arch) {
                    return val.__name__;
                }
            }
        }
    } except Exception {
        ;
    }
    return None;
}

"""Detect whether a filter lambda contains attribute predicates.

The topology index resolves type-only filters (`isinstance(i, T)`).
Anything more complex -- attribute access (`i.priority`), comparison
ops (`>=`, `==`, `in`, `is`) -- exceeds what the index can express,
so the planner has to bail out and let the linear path evaluate the
lambda directly.

The codegen emits these filters as plain Python lambdas
(see PyastGenPass.exit_filter_compr). Bytecode opcodes give us a
cheap, robust signal: pure type checks compile to LOAD_GLOBAL +
CALL_FUNCTION + RETURN, while predicates introduce LOAD_ATTR or a
COMPARE_OP. Conservative on inspection failure (assume predicates
present) so we never silently skip filtering.
"""
impl _filter_has_predicates(filt: (Callable | None)) -> bool {
    if filt is None {
        return False;
    }
    import dis;
    try {
        opcodes = {instr.opname for instr in dis.get_instructions(filt)};
    } except (TypeError, AttributeError, ValueError) {
        return True;
    }
    return bool(opcodes & {'LOAD_ATTR','COMPARE_OP','CONTAINS_OP','IS_OP'});
}

"""Use the topology index to resolve which node UUIDs will survive
the type-only filters in a path chain."""
impl plan_query(path: Any) -> (set[UUID] | None) {
    if not _is_enabled() {
        return None;
    }
    if not path.origin {
        return None;
    }
    origin_anchor = path.origin[0].__jac__;
    if not origin_anchor.persistent {
        return None;
    }
    root_anchor = _get_root_anchor(origin_anchor);
    if root_anchor is None {
        return None;
    }
    # Build the chain before fetching the index — if no hop has a filter we
    # can skip the decode entirely below. The index can only resolve type-only
    # filters; bail when a hop's edge filter has predicates, or when a
    # non-final node filter has predicates (the runtime post-applies the
    # final hop's node filter on the planned set so its predicates are safe).
    chain: list[tuple[(str | None), (str | None), int]] = [];
    destinations = path.destinations[:-1] if path.edge_only else path.destinations;
    has_filter = False;
    last_idx = len(destinations) - 1;
    for (i, dest) in enumerate(destinations) {
        if _filter_has_predicates(dest.`edge) {
            return None;
        }
        if i != last_idx and _filter_has_predicates(dest.nd) {
            return None;
        }
        edge_type = _extract_type_name_from_filter(dest.`edge);
        node_type = _extract_type_name_from_filter(dest.nd);
        chain.append((edge_type, node_type, dest.direction.value));
        if edge_type is not None or node_type is not None {
            has_filter = True;
        }
    }
    if not chain {
        return None;
    }
    # No filters anywhere in the chain — the natural edge-walk is optimal,
    # so skip the index entirely (avoids decoding the blob for nothing).
    if not has_filter {
        return None;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    origin_ids = {nd.__jac__.id for nd in path.origin};
    return idx.resolve_chain(origin_ids, chain);
}

"""Load nodes by UUID set, preserving edge-list order from origin nodes.

Walks each origin node's edges in their natural order and yields targets
whose ID is in the planned set. This preserves the same traversal order
as the non-indexed edges_to_nodes path.
"""
impl batch_load_nodes(node_ids: set[UUID], origin: (list | None) = None) -> list[Any] {
    import from jaclang { JacRuntimeInterface as Jac }
    ctx = Jac.get_context();
    import from jaclang.jac0core.archetype { NodeAnchor }

    # Load all needed nodes in one batch to avoid N+1 queries on DB backends.
    import from jaclang.runtimelib.memory { TieredMemory }
    if isinstance(ctx.mem, TieredMemory) {
        loaded: dict = ctx.mem.batch_get(list(node_ids));
    } else {
        loaded: dict = {
            nid: a
            for nid in node_ids
            if (a := ctx.mem.get(nid))
        };
    }

    if origin {
        # Prefetch edge anchors so the ordered walk doesn't trigger
        # N individual DB loads for edge stubs.
        if isinstance(ctx.mem, TieredMemory) {
            edge_ids = [e.id for nd in origin for e in nd.__jac__.edges];
            if edge_ids {
                ctx.mem.batch_get(edge_ids);
            }
        }
        seen: set = set();
        result = [];
        for nd in origin {
            nanch = nd.__jac__;
            for eanch in nanch.edges {
                tgt = eanch.target;
                if tgt and tgt.id in node_ids and tgt.id not in seen {
                    seen.add(tgt.id);
                    anchor = loaded.get(tgt.id);
                    if isinstance(anchor, NodeAnchor) and anchor.archetype {
                        result.append(anchor.archetype);
                    }
                }
                src = eanch.source;
                if src
                and src.id in node_ids
                and src.id != nanch.id
                and src.id not in seen {
                    seen.add(src.id);
                    anchor = loaded.get(src.id);
                    if isinstance(anchor, NodeAnchor) and anchor.archetype {
                        result.append(anchor.archetype);
                    }
                }
            }
        }
        return result;
    }

    # No origin — return in arbitrary order
    return [
        a.archetype
        for a in loaded.values()
        if isinstance(a, NodeAnchor) and a.archetype
    ];
}

"""Storage-layer pagination via the topology index.

Phase 1 scope: single-hop chains only. For multi-hop, the cross-hop ordering
semantics aren't well-defined (each hop's set-intersection step loses order),
so we fall back to the existing plan_query path which materializes everything
and slices in Python.

Returns None to signal "no pushdown" — callers fall back to the unsliced fast
path or to the slow path."""
impl plan_query_ordered(path: Any, slc: slice) -> (list[UUID] | None) {
    if not _is_enabled() {
        return None;
    }
    if not path.origin {
        return None;
    }
    origin_anchor = path.origin[0].__jac__;
    if not origin_anchor.persistent {
        return None;
    }
    root_anchor = _get_root_anchor(origin_anchor);
    if root_anchor is None {
        return None;
    }
    destinations = path.destinations[:-1] if path.edge_only else path.destinations;
    # Phase 1: single-hop only. Multi-hop pushdown requires defining ordering
    # across set-intersection steps; defer until there's a concrete request.
    if len(destinations) != 1 {
        return None;
    }
    dest = destinations[0];
    if _filter_has_predicates(dest.`edge) {
        return None;
    }
    # Predicates on the final hop's node filter are tolerated by plan_query
    # (the caller post-applies them); but post-applying *then* slicing changes
    # the ordering invariant we're trying to provide. Restrict to type-only.
    if _filter_has_predicates(dest.nd) {
        return None;
    }
    edge_type = _extract_type_name_from_filter(dest.`edge);
    node_type = _extract_type_name_from_filter(dest.nd);
    if edge_type is None and node_type is None {
        # Unfiltered single-hop slice: the natural edge-walk preserves order
        # cheaply, but pushdown still wins because we skip the edge-anchor
        # bulk prefetch. Plan as a wildcard chain entry.
        ;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    origin_ids = {nd.__jac__.id for nd in path.origin};
    return idx.resolve_chain_ordered(
        origin_ids, edge_type, node_type, dest.direction.value, slc
    );
}

"""Load nodes by an ordered list of UUIDs.

Used by the slice-pushdown fast path: the planner has already determined the
bounded set in canonical order, so we just batch-load and preserve order.
This skips the edge-anchor bulk prefetch that the unsliced path needs for
ordering — the topology index already encoded the ordering, so the storage
layer is asked for exactly the requested subset."""
impl batch_load_nodes_by_ids(node_ids: list[UUID]) -> list[Any] {
    import from jaclang { JacRuntimeInterface as Jac }
    import from jaclang.jac0core.archetype { NodeAnchor }
    import from jaclang.runtimelib.memory { TieredMemory }
    if not node_ids {
        return [];
    }
    ctx = Jac.get_context();
    if isinstance(ctx.mem, TieredMemory) {
        loaded: dict = ctx.mem.batch_get(node_ids);
    } else {
        loaded: dict = {
            nid: a
            for nid in node_ids
            if (a := ctx.mem.get(nid))
        };
    }
    result: list = [];
    for nid in node_ids {
        anchor = loaded.get(nid);
        if (
            isinstance(anchor, NodeAnchor)
            and anchor.archetype
            and Jac.check_read_access(anchor)
        ) {
            result.append(anchor.archetype);
        }
    }
    return result;
}
