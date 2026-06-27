"""Query planner implementation."""

import from typing { cast }

import from jaclang.runtimelib.query_utils { _trace_enabled, _materialize_ids }


"""Log the chosen strategy for a plan. No-op when trace is off."""
def _trace(strategy: str, plan: QueryPlan, extra: str = '') -> None {
    if not _trace_enabled() {
        return;
    }
    suffix = f" {extra}" if extra else '';
    logger.info(f"[query] {strategy} {plan.repr()}{suffix}");
}


"""Resolve the root anchor for a query plan via the memory layer.
Returns None if the plan has no root_id or the lookup fails."""
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


"""Build the chain triples (`(edge_type, node_type, direction)`) the
TopologyIndex expects from a list of HopSpec."""
def _chain_triples(chain: list[any]) -> list[tuple[(str | None), (str | None), int]] {
    return [(h.edge_type, h.node_type, h.direction) for h in chain];
}


"""Narrow the plan via the topology_index on the given root.

Returns the set of candidate UUIDs the chain resolves to, or None when the
index isn't usable (disabled, missing, or empty). The chain comes from the
plan; the function ignores `plan.id_in` (the caller decides whether to AND
the existing narrowing with the new one).
"""
def _topology_narrow(root_anchor: any, plan: QueryPlan) -> (set[UUID] | None) {
    if not plan.chain {
        return None;
    }
    import from jaclang.runtimelib.topology_index { TopologyIndex }
    idx = root_anchor.get_topology_index();
    if not isinstance(idx, TopologyIndex) or len(idx) == 0 {
        return None;
    }
    # bail_on_intermediate_foreign=True: when a non-final chain hop lands on
    # a node owned by a *different* root, that node's outgoing edges live in
    # its own root's index — not this one. Continuing here would silently
    # undercount. Bail and let the caller fall back to the slow path (which
    # walks the in-memory edge graph and crosses roots transparently).
    return idx.resolve_chain(
        {plan.root_id}, _chain_triples(plan.chain), bail_on_intermediate_foreign=True
    );
}


"""Pure-floor execution: topology_index → batch_get.

Used when the backend declares no useful capabilities, or to back up a
backend that returned no results from a partial pushdown."""
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


"""Pushdown execution: backend handles the whole plan."""
def _execute_pushdown(mem: any, plan: QueryPlan) -> list[any] {
    _trace('pushdown', plan);
    result: list = [];
    for anchor in mem.execute_plan(plan) {
        # post_filter is the user's `node_filter` lambda — takes archetype.
        if (
            plan.post_filter is not None
            and anchor.archetype is not None
            and not plan.post_filter(anchor.archetype)
        ) {
            continue;
        }
        result.append(anchor);
    }
    # Honor slice if the backend doesn't have 'slice' capability — planner
    # only adds 'slice' to needs when slc is set, so if we got here without
    # the backend covering it, the caller is depending on us to apply.
    if plan.slc is not None and 'slice' not in mem.capabilities() {
        result = result[plan.slc];
    }
    return result;
}


"""Mixed execution: topology narrows, backend materializes via `id_in`.

The planner uses this when the backend can handle field predicates but not
the full chain (the common case for type+field queries against Mongo). The
topology_index gives us the candidate set for free; the backend then runs
`_id IN (...) AND field_predicates...` in a single round-trip — much better
than batch_get + Python filtering for large candidate sets with sparse field
matches.
"""
def _execute_mixed(mem: any, plan: QueryPlan, narrowed: set[UUID]) -> list[any] {
    # Build a reduced plan: chain is consumed (narrowing did its job), id_in
    # carries the candidate set, field_predicates and node_type_final are
    # preserved for the backend.
    reduced = QueryPlan(
        root_id=plan.root_id,
        chain=[],
        field_predicates=plan.field_predicates,
        id_in=narrowed,
        slc=plan.slc,
        node_type_final=plan.node_type_final,
        post_filter=None  # applied above
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
    # Backend can't handle the reduced plan; fall back to pure floor with the
    # narrowing we already computed.
    _trace('mixed→floor', plan, f"narrowed={len(narrowed)}");
    return _materialize_ids(
        mem, list(narrowed), post_filter=plan.post_filter, slc=plan.slc
    );
}


"""Strategy chooser. See module docstring for the decision tree."""
impl execute_plan(mem: any, plan: QueryPlan) -> list[any] {
    if plan.is_trivial() {
        _trace('skip:trivial', plan);
        return [];
    }
    caps = mem.capabilities();
    needs = plan.needs();

    # 1. Full pushdown — backend covers everything the plan asks for.
    if needs <= caps {
        return _execute_pushdown(mem, plan);
    }

    # 2. Try mixed strategy: narrow via topology_index, then push the
    # `id_in + field_predicates` to the backend if it covers those.
    root_anchor = _get_root_anchor(mem, plan);
    if root_anchor is not None and plan.chain {
        narrowed = _topology_narrow(root_anchor, plan);
        if narrowed is not None {
            return _execute_mixed(mem, plan, narrowed);
        }
    }

    # 3. Floor: pure topology_index → batch_get.
    if root_anchor is not None {
        return _execute_floor(mem, plan, root_anchor);
    }
    _trace('skip:no-root', plan);
    return [];
}


"""High-level path entry point. Thin wrapper around the per-hop resolver
in `jaclang.runtimelib.resolver`. Kept for source compatibility with
callers that import `execute_path` directly (notably the planner-
correctness tests in `jac/tests/runtimelib/test_topology_e2e.jac`).

Always returns a list — the legacy `None` signal is gone now that the
resolver folds per-hop and never bails the whole query."""
impl execute_path(mem: any, path: any, slc: (slice | None) = None) -> list[any] {
    import from jaclang.runtimelib.resolver { resolve_path_anchors }
    return resolve_path_anchors(mem, path, slc);
}
