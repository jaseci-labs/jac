"""Per-hop resolver implementation."""

import from typing { cast }

import from jaclang.runtimelib.query_utils {
    _trace_enabled,
    _filter_type_name,
    _filter_has_predicates,
    _materialize_ids,
    _path_root_anchor
}


"""Emit a single per-hop trace line. No-op when JAC_QUERY_TRACE is off."""
def _trace_hop(
    strategy: str,
    hop_idx: int,
    in_count: int,
    out_count: int,
    hop: ChainHop,
    extra: str = ''
) -> None {
    if not _trace_enabled() {
        return;
    }
    edge_label = hop.edge_type or '*';
    node_label = hop.node_type or '*';
    suffix = f" {extra}" if extra else '';
    logger.info(
        f"[query] hop[{hop_idx}]:{strategy} edge={edge_label} node={node_label}"
        f" dir={hop.direction} in={in_count} out={out_count}{suffix}"
    );
}


"""Emit a final-step trace line for materialization decisions. The fold itself
is logged per-hop; this captures the post-fold step (pushdown vs. batch_get)
so the JAC_QUERY_TRACE output describes the whole call."""
def _trace_final(strategy: str, narrowed: int, extra: str = '') -> None {
    if not _trace_enabled() {
        return;
    }
    suffix = f" {extra}" if extra else '';
    logger.info(f"[query] final:{strategy} narrowed={narrowed}{suffix}");
}


"""Backend pushdown: hand a reduced plan to `mem.execute_plan` and apply the
post_filter / slice fallback locally when capabilities don't cover them.

Plans built by `resolve_path_anchors` are node-resolving (chain consumed,
`id_in` carries node IDs); backends yield `NodeAnchor` for that shape."""
def _try_pushdown(mem: Memory, plan: QueryPlan) -> list[NodeAnchor] {
    result: list[NodeAnchor] = [];
    for anchor in mem.execute_plan(plan) {
        if (
            plan.post_filter is not None
            and anchor.archetype is not None
            and not plan.post_filter(anchor.archetype)
        ) {
            continue;
        }
        result.append(cast(NodeAnchor, anchor));
    }
    if plan.slc is not None and 'slice' not in mem.capabilities() {
        result = result[plan.slc];
    }
    return result;
}


"""Construct the per-hop chain from a path. No bail conditions: every
destination becomes a ChainHop, with type names lifted from the filter
lambdas where possible. Hops the index can't cover are handled at fold
time via `_hop_via_walk`, not by rejecting the whole chain up front."""
def _build_hops(path: ObjectSpatialPath) -> list[ChainHop] {
    destinations = path.destinations[:-1] if path.edge_only else path.destinations;
    chain: list[ChainHop] = [];
    for dest in destinations {
        chain.append(
            ChainHop(
                dest=dest,
                edge_type=_filter_type_name(dest.`edge),
                node_type=_filter_type_name(dest.nd),
                direction=dest.direction.value,
            )
        );
    }
    return chain;
}


"""Per-hop anchor walk. Materialize the current ID set to node archetypes
and run a single `edges_to_nodes` call. The walk crosses roots, applies
the destination's callable filters (edge filter + node filter), and works
on transient anchors — covering every case the topology index doesn't."""
def _hop_via_walk(
    mem: Memory, ids: set[UUID], dest: ObjectSpatialDestination
) -> set[UUID] {
    import from jaclang { JacRuntimeInterface }
    anchors = _materialize_ids(mem, list(ids));
    archetypes: list[NodeArchetype] = [
        cast(NodeArchetype, a.archetype)
        for a in anchors
        if a.archetype is not None
    ];
    next_nodes = JacRuntimeInterface.edges_to_nodes(archetypes, dest);
    return {cast(UUID, n.__jac__.id) for n in next_nodes};
}


"""Ordered variant of `_hop_via_walk` for the final-hop ordered branch.
`edges_to_nodes` already walks `nanch.edges` in insertion order; this
preserves that order so the slice has the same semantics as today's
single-hop linear traversal."""
def _hop_via_walk_ordered(
    mem: Memory, ids: set[UUID], dest: ObjectSpatialDestination, slc: slice
) -> list[UUID] {
    import from jaclang { JacRuntimeInterface }
    anchors = _materialize_ids(mem, list(ids));
    archetypes: list[NodeArchetype] = [
        cast(NodeArchetype, a.archetype)
        for a in anchors
        if a.archetype is not None
    ];
    next_nodes = JacRuntimeInterface.edges_to_nodes(archetypes, dest);
    ordered: list[UUID] = [cast(UUID, n.__jac__.id) for n in next_nodes];
    return ordered[slc];
}


"""Decode the root's topology index once per `refs()`. Returns None when
there's no root anchor or the index isn't usable (missing, wrong type, or
empty). Callers thread the result through the fold so `resolve_hop`
doesn't re-decode on every hop — decode is `O(edges)` and the index can
hold tens of thousands of edges."""
def _get_usable_index(root_anchor: (NodeAnchor | None)) -> (TopologyIndex | None) {
    if root_anchor is None {
        return None;
    }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    return idx;
}


"""Walk the chain prefix uniformly. No foreign-root guard, no None
propagation — each hop's `resolve_hop` succeeds on its own (index or walk),
so the fold never has to bail."""
def _resolve_prefix(
    mem: Memory,
    ids: set[UUID],
    prefix_hops: list[ChainHop],
    idx: (TopologyIndex | None)
) -> set[UUID] {
    current: set[UUID] = ids;
    for (i, hop) in enumerate(prefix_hops) {
        next_ids = resolve_hop(mem, current, hop, idx, i, slc=None);
        # Intermediate hops always pass slc=None → resolve_hop returns set.
        current = cast(set[UUID], next_ids);
    }
    return current;
}


impl resolve_hop(
    mem: Memory,
    current_ids: set[UUID],
    hop: ChainHop,
    idx: (TopologyIndex | None),
    hop_idx: int,
    slc: (slice | None) = None
) -> (set[UUID] | list[UUID]) {
    # The index covers this hop only when:
    #   (a) no predicate filters (edge or node) — the index can only filter
    #       on type names, not on lambda bodies.
    #   (b) the caller passed a usable index (decoded once per `refs()` in
    #       `resolve_path_anchors`; None for transient origins or absent
    #       topology data).
    #   (c) every input ID is owned by this root — foreign-root IDs have
    #       their edges in a different index that this one can't see.
    has_pred = (
        _filter_has_predicates(hop.dest.nd) or _filter_has_predicates(hop.dest.`edge)
    );
    in_count = len(current_ids);
    if not has_pred and idx is not None {
        import from jaclang.runtimelib.topology_index { SELF_ROOT }
        if all(
            (lid := idx.node_to_lid.get(uid)) is not None
            and idx.node_table[lid][2] == SELF_ROOT for uid in current_ids
        ) {
            if slc is not None {
                ordered = idx.resolve_chain_ordered(
                    current_ids, hop.edge_type, hop.node_type, hop.direction, slc
                );
                _trace_hop(
                    'index:ordered',
                    hop_idx,
                    in_count,
                    len(ordered),
                    hop,
                    f"slc={slc.start}:{slc.stop}"
                );
                return ordered;
            }
            triple = (hop.edge_type, hop.node_type, hop.direction);
            narrowed = idx.resolve_chain(current_ids, [triple]);
            if narrowed is not None {
                _trace_hop('index:set', hop_idx, in_count, len(narrowed), hop);
                return narrowed;
            }
        }
    }
    # Per-hop walk fallback. Handles predicates, foreign roots, missing
    # index, and any shape `resolve_chain` declines.
    if slc is not None {
        walked_ordered = _hop_via_walk_ordered(mem, current_ids, hop.dest, slc);
        _trace_hop(
            'walk:ordered',
            hop_idx,
            in_count,
            len(walked_ordered),
            hop,
            f"slc={slc.start}:{slc.stop}"
        );
        return walked_ordered;
    }
    walked = _hop_via_walk(mem, current_ids, hop.dest);
    _trace_hop('walk:set', hop_idx, in_count, len(walked), hop);
    return walked;
}


"""High-level path entry. Always returns a list — never None.

  1. Empty origin → `[]`.
  2. Transient origin (anchor not in `mem`) → inline archetype walk; can't
     use the per-hop fold because batch_get materialization assumes anchors
     are loadable from `mem`.
  3. Otherwise: per-hop fold via `_resolve_prefix` + `resolve_hop`. The fold
     itself never bails — each hop locally picks index or walk.
  4. Materialization: ordered final-hop results go straight to
     `_materialize_ids`; set results try backend pushdown first (parity with
     today's set-narrowing branch — needed for Mongo's `id_in + type_pushdown`
     queries even when the user didn't pass a slice).
"""
impl resolve_path_anchors(
    mem: Memory, path: ObjectSpatialPath, slc: (slice | None) = None
) -> list[NodeAnchor] {
    if not path.origin {
        return [];
    }
    chain = _build_hops(path);
    if not chain {
        # Caller landed here with no hops — return origin anchors. Practical
        # only when `path.edge_only=True` with a single destination, and the
        # caller (refs()) handles that shape via the edge terminator before
        # ever calling us. Defensive default for direct callers.
        return [nd.__jac__ for nd in path.origin];
    }

    # Transient origins aren't in `mem`; the per-hop fold's batch_get
    # materialization would lose them. Run the linear archetype walk
    # directly — same shape as the legacy slow loop.
    if not path.origin[0].__jac__.persistent {
        import from jaclang { JacRuntimeInterface }
        origin: list[NodeArchetype] = path.origin;
        destinations = path.destinations[:-1] if path.edge_only else path.destinations;
        for dest in destinations {
            origin = JacRuntimeInterface.edges_to_nodes(origin, dest);
        }
        anchors: list[NodeAnchor] = [n.__jac__ for n in origin];
        if slc is not None {
            anchors = anchors[slc];
        }
        return anchors;
    }

    root_anchor = _path_root_anchor(mem, path);
    # Decode the topology index once per `refs()` call. `get_topology_index`
    # is a full deserialization of the on-disk blob; threading the decoded
    # form through the fold avoids `len(chain)` redundant decodes per query.
    idx = _get_usable_index(root_anchor);
    current: set[UUID] = {cast(UUID, nd.__jac__.id) for nd in path.origin};
    if len(chain) > 1 {
        current = _resolve_prefix(mem, current, chain[:-1], idx);
    }
    last_hop = chain[-1];
    last_has_post_filter = _filter_has_predicates(last_hop.dest.nd);
    post_filter: (Callable[[Archetype], bool] | None) = (
        last_hop.dest.node_filter if last_has_post_filter else None
    );
    use_ordered = (not last_has_post_filter) and (slc is not None or len(chain) == 1);
    effective_slc: (slice | None) = None;
    if use_ordered {
        effective_slc = slc if slc is not None else slice(None, None, None);
    }
    result = resolve_hop(mem, current, last_hop, idx, len(chain) - 1, effective_slc);
    if isinstance(result, list) {
        return _materialize_ids(mem, result);
    }
    # Set narrowing → try backend pushdown when we have a root and the
    # capabilities cover the reduced plan.
    if root_anchor is not None {
        plan = QueryPlan(
            root_id=root_anchor.id,
            chain=[],
            id_in=result,
            node_type_final=last_hop.node_type,
            slc=slc,
            post_filter=post_filter,
        );
        if plan.needs() <= mem.capabilities() {
            _trace_final('pushdown', len(result));
            return _try_pushdown(mem, plan);
        }
    }
    _trace_final('floor', len(result));
    return _materialize_ids(mem, list(result), post_filter=post_filter, slc=slc);
}
