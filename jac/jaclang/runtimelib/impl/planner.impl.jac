import from typing { cast }

import from jaclang.runtimelib.query_utils { _trace_enabled, _materialize_ids }


def _trace(strategy: str, plan: QueryPlan, extra: str = '') -> None {
    if not _trace_enabled() {
        return;
    }
    suffix = f" {extra}" if extra else '';
    logger.info(f"[query] {strategy} {plan.repr()}{suffix}");
}


def _get_root_anchor(mem: any, plan: QueryPlan) -> any {
    if plan.root_id is None {
        return None;
    }
    try {
        anchor = mem.get(plan.root_id);
        import from jaclang.jac0core.archetype { NodeAnchor }
        if isinstance(anchor, NodeAnchor) {
            return anchor;
        }
    } except Exception {
        ;
    }
    return None;
}


def _chain_triples(chain: list[any]) -> list[tuple[(str | None), (str | None), int]] {
    return [(h.edge_type, h.node_type, h.direction) for h in chain];
}


def _topology_narrow(root_anchor: any, plan: QueryPlan) -> (set[UUID] | None) {
    if not plan.chain {
        return None;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }

    return idx.resolve_chain(
        {plan.root_id}, _chain_triples(plan.chain), bail_on_intermediate_foreign=True
    );
}


def _execute_floor(mem: any, plan: QueryPlan, root_anchor: any) -> list[any] {
    candidate_ids: (set[UUID] | None) = plan.id_in;
    if candidate_ids is None {
        candidate_ids = _topology_narrow(root_anchor, plan);
        if candidate_ids is None {
            _trace('floor:bail-no-index', plan);
            return [];
        }
    }
    _trace('floor', plan, f"candidates={len(candidate_ids)}");
    return _materialize_ids(
        mem, list(candidate_ids), post_filter=plan.post_filter, slc=plan.slc
    );
}


def _execute_pushdown(mem: any, plan: QueryPlan) -> list[any] {
    _trace('pushdown', plan);
    result: list = [];
    for anchor in mem.execute_plan(plan) {
        if (
            plan.post_filter is not None
            and anchor.archetype is not None
            and not plan.post_filter(anchor.archetype)
        ) {
            continue;
        }
        result.append(anchor);
    }

    if plan.slc is not None and 'slice' not in mem.capabilities() {
        result = result[plan.slc];
    }
    return result;
}


def _execute_mixed(mem: any, plan: QueryPlan, narrowed: set[UUID]) -> list[any] {
    reduced = QueryPlan(
        root_id=plan.root_id,
        chain=[],
        field_predicates=plan.field_predicates,
        id_in=narrowed,
        slc=plan.slc,
        node_type_final=plan.node_type_final,
        post_filter=None
    );
    caps = mem.capabilities();
    if reduced.needs() <= caps {
        _trace('mixed', plan, f"narrowed={len(narrowed)}");
        result: list = [];
        for anchor in mem.execute_plan(reduced) {
            if plan.post_filter is not None and not plan.post_filter(anchor) {
                continue;
            }
            result.append(anchor);
        }
        if plan.slc is not None and 'slice' not in caps {
            result = result[plan.slc];
        }
        return result;
    }

    _trace('mixed→floor', plan, f"narrowed={len(narrowed)}");
    return _materialize_ids(
        mem, list(narrowed), post_filter=plan.post_filter, slc=plan.slc
    );
}


impl execute_plan(mem: any, plan: QueryPlan) -> list[any] {
    if plan.is_trivial() {
        _trace('skip:trivial', plan);
        return [];
    }
    caps = mem.capabilities();
    needs = plan.needs();

    if needs <= caps {
        return _execute_pushdown(mem, plan);
    }

    root_anchor = _get_root_anchor(mem, plan);
    if root_anchor is not None and plan.chain {
        narrowed = _topology_narrow(root_anchor, plan);
        if narrowed is not None {
            return _execute_mixed(mem, plan, narrowed);
        }
    }

    if root_anchor is not None {
        return _execute_floor(mem, plan, root_anchor);
    }
    _trace('skip:no-root', plan);
    return [];
}


impl execute_path(mem: any, path: any, slc: (slice | None) = None) -> list[any] {
    import from jaclang.runtimelib.resolver { resolve_path_anchors }
    return resolve_path_anchors(mem, path, slc);
}


impl plan_chain(
    root_anchor: any,
    origin_ids: set[UUID],
    chain: list[tuple[(str | None), (str | None), int]]
) -> (set[UUID] | None) {
    if root_anchor is None or not chain {
        return None;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    return idx.resolve_chain(origin_ids, chain, bail_on_intermediate_foreign=True);
}


impl plan_chain_ordered(
    root_anchor: any,
    origin_ids: set[UUID],
    chain: list[tuple[(str | None), (str | None), int]],
    slc: slice
) -> (list[UUID] | None) {
    if root_anchor is None or not chain {
        return None;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }

    if len(chain) > 1 {
        prev = idx.resolve_chain(origin_ids, chain[:-1]);
        if not prev {
            return [];
        }
        origin_ids = prev;
    }
    (f_edge, f_node, f_dir) = chain[-1];
    return idx.resolve_chain_ordered(origin_ids, f_edge, f_node, f_dir, slc);
}
