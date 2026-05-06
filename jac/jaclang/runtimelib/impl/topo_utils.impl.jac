"""Topology utils implementation."""

"""Check if topology_index is enabled in config."""
impl _is_enabled -> bool {
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
    # Ensure root node itself is in the index
    idx.add_node(root_anchor.id, _type_name(root_anchor.archetype));
    # Add source node
    idx.add_node(
        source.id,
        _type_name(source.archetype),
        None if source.root == root_anchor.id else source.root
    );
    # Add target node
    target_owner = None;
    if target.root and target.root != root_anchor.id {
        target_owner = target.root;
    }
    idx.add_node(target.id, _type_name(target.archetype), target_owner);
    # Add edge
    idx.add_edge(source.id, target.id, _type_name(`edge.archetype));
    # If undirected, add reverse edge too
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
    # Ensure root is in index
    idx.add_node(root_anchor.id, _type_name(root_anchor.archetype));
    # Add/update node
    idx.add_node(node_anchor.id, _type_name(node_anchor.archetype));
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
    # Check if the filter itself is an Archetype instance (identity filter)
    try {
        import from jaclang.jac0core.archetype { Archetype }
        if isinstance(filt, Archetype) {
            return `type(filt).__name__;
        }
    } except Exception {
        ;
    }
    # Try to inspect closure variables for a type
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
    # Get the root's topology index from the origin nodes
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
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    # Build the chain of (edge_type, node_type, direction).
    #
    # The index can only resolve type-only filters. The runtime caller
    # post-applies the FINAL destination's node filter on the planned
    # set (see edges_to_nodes in runtime.impl), so node predicates on
    # that last hop are safe -- their `nd` lambda gets re-evaluated.
    # Anything else -- an edge predicate at any hop, or a node
    # predicate on a non-final hop -- would be silently dropped if we
    # planned it, so we bail and let the linear path handle it.
    chain: list[tuple[(str | None), (str | None), int]] = [];
    destinations = path.destinations[:-1] if path.edge_only else path.destinations;
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
    }
    if not chain {
        return None;
    }
    # Resolve using the index — authoritative when present
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
        # Walk edges in order, only emit targets in the planned set
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
