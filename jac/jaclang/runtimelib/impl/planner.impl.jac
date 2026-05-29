"""Query planner implementation."""

import inspect;
import dis;
import from typing { cast }


"""Truthy `JAC_QUERY_TRACE` toggles per-call strategy/needs/coverage logging.
Reads each call; cheap enough and lets users flip it without restarting."""
def _trace_enabled -> bool {
    val = os.environ.get('JAC_QUERY_TRACE', '');
    return val.lower() in ('1', 'true', 'yes', 'on');
}


"""Inspect a Jac-emitted filter lambda for archetype-type identity.

Returns the archetype class name if the lambda is a pure `isinstance(i, T)`
check (or an Archetype instance acting as an identity filter). Returns None
when the filter is None or non-trivial.
"""
def _filter_type_name(filt: any) -> (str | None) {
    if filt is None {
        return None;
    }
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


"""Detect whether a filter lambda contains predicate ops beyond type checks.

Codegen emits filters as plain Python lambdas. Pure `isinstance(i, T)` checks
compile to LOAD_GLOBAL + CALL_FUNCTION + RETURN; predicates introduce
LOAD_ATTR / COMPARE_OP / CONTAINS_OP / IS_OP. Conservative on inspection
failure — assume predicates present so we never silently skip filtering.
"""
def _filter_has_predicates(filt: any) -> bool {
    if filt is None {
        return False;
    }
    try {
        opcodes = {instr.opname for instr in dis.get_instructions(filt)};
    } except (TypeError, AttributeError, ValueError) {
        return True;
    }
    return bool(opcodes & {'LOAD_ATTR', 'COMPARE_OP', 'CONTAINS_OP', 'IS_OP'});
}


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


"""Materialize a set of UUIDs to NodeAnchors via `batch_get`, applying
optional post_filter and slice. Decoupled from QueryPlan so callers can opt
out of either dimension (e.g. when the slice was already applied upstream)."""
def _materialize_ids(
    mem: any, ids: list[UUID], post_filter: any = None, slc: (slice | None) = None
) -> list[any] {
    if not ids {
        return [];
    }
    import from jaclang.runtimelib.memory { TieredMemory }
    import from jaclang.jac0core.archetype { NodeAnchor }
    if isinstance(mem, TieredMemory) {
        loaded: dict = mem.batch_get(ids);
    } else {
        loaded: dict = {
            i: a
            for i in ids
            if (a := mem.get(i))
        };
    }
    result: list = [];
    for i in ids {
        anchor = loaded.get(i);
        if isinstance(anchor, NodeAnchor) and anchor.archetype {
            # The post_filter is the destination's `node_filter` lambda from
            # the user's path expression — it takes an *archetype*, not the
            # anchor. The lambda body reads attributes like `n.val`, so it
            # has to see the user-facing archetype object.
            if post_filter is not None and not post_filter(anchor.archetype) {
                continue;
            }
            result.append(anchor);
        }
    }
    if slc is not None {
        result = result[slc];
    }
    return result;
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


"""Resolve the root anchor that owns an ObjectSpatialPath's origin.

This bridges the `path.origin` (a list of NodeArchetype objects) to the
NodeAnchor that holds the topology_index. Returns None when the origin
isn't persistent or its owning root can't be found.
"""
def _path_root_anchor(mem: any, path: any) -> any {
    if not path.origin {
        return None;
    }
    origin_anchor = path.origin[0].__jac__;
    if not origin_anchor.persistent {
        return None;
    }
    import from jaclang.jac0core.archetype { NodeAnchor, Root }
    # The origin might BE the root.
    if origin_anchor.root is None {
        if isinstance(origin_anchor, NodeAnchor)
        and isinstance(origin_anchor.archetype, Root) {
            return origin_anchor;
        }
        return None;
    }
    try {
        `root = mem.get(origin_anchor.root);
        if isinstance(`root, NodeAnchor) {
            return `root;
        }
    } except Exception {
        ;
    }
    return None;
}


"""Build a QueryPlan from an `ObjectSpatialPath` + optional slice.

Returns None when the path isn't pushdown-eligible — any hop with a predicate
filter (attribute access / comparison), or a chain that has no filter at all
(natural edge-walk is optimal anyway).

The plan carries:
  * `chain`              one HopSpec per destination, with type names lifted
                         from the filter lambdas via `_filter_type_name`.
  * `node_type_final`    mirror of the last hop's node_type — gives the
                         backend a cheap arch_type filter when chain is empty.
  * `post_filter`        the final hop's node filter callable (if it has
                         predicates and is therefore not type-only); the
                         planner applies it above any backend result.
  * `slc`                passed through verbatim; backends with `'slice'`
                         capability can push it down.

The root_id is set from the path's origin so the planner can fetch the
topology_index.
"""
def _build_plan_from_path(
    mem: any, path: any, slc: (slice | None) = None
) -> (QueryPlan | None) {
    if not path.origin {
        return None;
    }
    origin_anchor = path.origin[0].__jac__;
    if not origin_anchor.persistent {
        return None;
    }
    destinations = path.destinations[:-1] if path.edge_only else path.destinations;
    if not destinations {
        return None;
    }
    import from jaclang.runtimelib.query_plan { HopSpec }
    chain: list[HopSpec] = [];
    last_idx = len(destinations) - 1;
    last_post_filter: any = None;
    has_filter = False;
    for (i, dest) in enumerate(destinations) {
        # Edge filter: type-only or bail.
        if _filter_has_predicates(dest.`edge) {
            return None;
        }
        # Non-final node filters must be type-only too; the final hop's
        # predicates can be applied post-narrowing as post_filter.
        node_has_pred = _filter_has_predicates(dest.nd);
        if i != last_idx and node_has_pred {
            return None;
        }
        edge_type = _filter_type_name(dest.`edge);
        node_type = _filter_type_name(dest.nd);
        chain.append(
            HopSpec(
                edge_type=edge_type, node_type=node_type, direction=dest.direction.value
            )
        );
        if edge_type is not None or node_type is not None {
            has_filter = True;
        }
        if i == last_idx and node_has_pred {
            last_post_filter = dest.node_filter;
        }
    }
    if not has_filter and last_post_filter is None {
        # No filter anywhere — natural edge-walk is optimal, skip the index.
        return None;
    }
    return QueryPlan(
        root_id=origin_anchor.root or origin_anchor.id,
        chain=chain,
        node_type_final=chain[-1].node_type if chain else None,
        slc=slc,
        post_filter=last_post_filter
    );
}


"""High-level path entry point. Builds a QueryPlan, runs it, returns NodeAnchors.

Strategy ladder, picked by query shape:

  * **sliced, no post_filter** → `plan_chain_ordered` (works for single-hop
    AND multi-hop; multi-hop resolves the prefix as a set then walks the
    final adj_list in order with the slice applied). This bounds L3 fetches
    to roughly the slice size — critical for paginated queries on large
    fanouts where the legacy unbounded path loaded the whole result first.

  * **single-hop, no slice, no post_filter** → `plan_chain_ordered` with a
    full-open slice. Canonical edge-walk order is preserved so existing
    visit semantics are unchanged from the legacy edge-walk path.

  * **anything else** (multi-hop unsliced, or any post_filter present) →
    set narrowing via `plan_chain`, then backend pushdown if capabilities
    cover the reduced plan, otherwise `batch_get`. post_filter applied
    above the materialized list before any leftover slicing.

Returns None to signal the caller should fall back to the legacy edge-walk.
"""
impl execute_path(
    mem: any, path: any, slc: (slice | None) = None
) -> (list[any] | None) {
    plan = _build_plan_from_path(mem, path, slc);
    if plan is None {
        return None;
    }
    root_anchor = _path_root_anchor(mem, path);
    if root_anchor is None {
        return None;
    }
    origin_ids: set[UUID] = {cast(UUID, nd.__jac__.id) for nd in path.origin};
    chain_triples = _chain_triples(plan.chain);

    # Ordered fast path covers single-hop walks AND sliced multi-hop. The
    # ordered resolver applies the slice itself, so materialize doesn't.
    use_ordered = plan.post_filter is None
    and (slc is not None or len(plan.chain) == 1);
    if use_ordered {
        effective_slc = slc if slc is not None else slice(None, None, None);
        ordered = plan_chain_ordered(
            root_anchor, origin_ids, chain_triples, effective_slc
        );
        if ordered is None {
            return None;
        }
        _trace('ordered', plan, f"ids={len(ordered)}");
        return _materialize_ids(mem, ordered);
    }

    # Set-narrowing branch: multi-hop without slice, or anything with a
    # post_filter (predicates invalidate the ordered slice invariant).
    narrowed = plan_chain(root_anchor, origin_ids, chain_triples);
    if narrowed is None {
        return None;
    }
    plan.id_in = narrowed;
    plan.chain = [];  # consumed by narrowing
    _trace('path', plan, f"narrowed={len(narrowed)}");

    # Backend pushdown if capable, else floor through batch_get.
    if plan.needs() <= mem.capabilities() {
        return _execute_pushdown(mem, plan);
    }
    return _materialize_ids(
        mem, list(narrowed), post_filter=plan.post_filter, slc=plan.slc
    );
}


"""Compatibility helper. Resolves a chain using the topology_index on the
given root and returns the resulting UUID set. None when not usable."""
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


"""Compatibility helper. Ordered single-hop resolution with slice applied."""
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
    # Multi-hop prefix resolves via the set-based walker; the final hop runs
    # ordered. Order between hops isn't observable to the slice.
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
