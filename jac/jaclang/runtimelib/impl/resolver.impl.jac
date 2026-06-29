import from typing { cast }

import from jaclang.runtimelib.query_utils {
    _trace_enabled,
    _filter_type_name,
    _filter_has_predicates,
    _materialize_ids,
    _path_root_anchor
}


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


def _trace_final(strategy: str, narrowed: int, extra: str = '') -> None {
    if not _trace_enabled() {
        return;
    }
    suffix = f" {extra}" if extra else '';
    logger.info(f"[query] final:{strategy} narrowed={narrowed}{suffix}");
}


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


def _resolve_prefix(
    mem: Memory,
    ids: set[UUID],
    prefix_hops: list[ChainHop],
    idx: (TopologyIndex | None)
) -> set[UUID] {
    current: set[UUID] = ids;
    for (i, hop) in enumerate(prefix_hops) {
        next_ids = resolve_hop(mem, current, hop, idx, i, slc=None);

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


impl resolve_path_anchors(
    mem: Memory, path: ObjectSpatialPath, slc: (slice | None) = None
) -> list[NodeAnchor] {
    if not path.origin {
        return [];
    }
    chain = _build_hops(path);
    if not chain {
        return [nd.__jac__ for nd in path.origin];
    }

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
