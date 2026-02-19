"""Implementation for TTG Generator constructs."""
import from jaclang.jac0core.archetype { VisitType }

"""Resolve a VisitType field (type or string name) to a concrete type.

Looks up string names in the reverse_type_map (name -> type) built from
type_map values. Returns None if unresolved.
"""
@ classmethod
impl JacTTGGenerator._resolve_type(
    cls: type[JacTTGGenerator],
    ref: (type | str | None),
    reverse_type_map: dict[(str, type)]
) -> (type | None) {
    if ref is None {
        return None;
    }
    if isinstance(ref, str) {
        return reverse_type_map.get(ref);
    }
    return ref;
}

"""Filter neighbors of a UUID based on walker visit types.

Uses type_map to resolve types and matches them against the
walker's VisitType constraints. No Jac archetypes are loaded.
"""
@ classmethod
impl JacTTGGenerator.filter_neighbors(
    cls: type[JacTTGGenerator],
    nd_id: UUID,
    visits: list,
    graph: list[tuple[(UUID, UUID, UUID)]],
    type_map: dict[(UUID, type)]
) -> list[tuple[(UUID, UUID)]] {
    filtered: list[tuple[(UUID, UUID)]] = [];
    # Build reverse lookup (name -> type) for string-based VisitType fields.
    reverse_type_map: dict[(str, type)] = {t.__name__: t for t in type_map.values()};
    # Get all outgoing edges from this UUID.
    edges_out = [
        e
        for e in graph
        if (e[0] == nd_id)
    ];
    nd_type = type_map.get(nd_id);
    # Filter visits applicable to this type.
    applicable_visits: list = [];
    for v in visits {
        if not isinstance(v, VisitType) {
            applicable_visits.append(v);
            continue;
        }
        resolved_from = cls._resolve_type(v.from_node_type, reverse_type_map);
        if (
            v.from_node_type is None
            or resolved_from is None
            or (nd_type is not None and issubclass(nd_type, resolved_from))
        ) {
            applicable_visits.append(v);
        }
    }
    seen_targets: set[UUID] = `set();
    for (src, eid, tgt) in edges_out {
        for v in applicable_visits {
            if isinstance(v, VisitType) {
                etype = type_map.get(eid);
                resolved_edge = cls._resolve_type(v.edge_type, reverse_type_map);
                if (
                    v.edge_type is None
                    or resolved_edge is None
                    or (etype is not None and issubclass(etype, resolved_edge))
                ) {
                    if (tgt not in seen_targets) {
                        filtered.append((eid, tgt));
                        seen_targets.add(tgt);
                    }
                }
            } else {
                # Non-VisitType entry (fallback: accept all).
                if (tgt not in seen_targets) {
                    filtered.append((eid, tgt));
                    seen_targets.add(tgt);
                }
            }
        }
    }
    return filtered;
}

"""Build a temporal trace graph from Root topology data.

BFS expansion from start_id using filtered neighbors.  Returns a tree
of TypedWalkerState plus helper structures for prefetching.
"""
@ classmethod
impl JacTTGGenerator.get_ttg(
    cls: type[JacTTGGenerator],
    warch: Any,
    start_id: UUID,
    graph: list[tuple[(UUID, UUID, UUID)]],
    type_map: dict[(UUID, type)]
) -> tuple[(TypedWalkerState, set[UUID], dict[(UUID, list[tuple[(UUID, UUID)]])])] {
    wtype_name = `type(warch).__name__;
    visits = getattr(warch, '__jac_ttg_visits__', []);
    ttg_root = TypedWalkerState(
        walker_type=wtype_name, depth=0, nd=start_id, incoming_edge=None, children=[]
    );
    queue: list[TypedWalkerState] = [ttg_root];
    visited_ids: set[UUID] = `set();
    existing_pairs: set[tuple[(UUID, UUID)]] = `set();
    child_map: dict[(UUID, list[tuple[(UUID, UUID)]])] = {};
    while queue {
        state = queue.pop(0);
        cur = state.nd;
        neighbors = cls.filter_neighbors(cur, visits, graph, type_map);
        for (eid, tgt) in neighbors {
            if (tgt in visited_ids) {
                continue;
            }
            visited_ids.add(tgt);
            if ((cur, tgt) in existing_pairs) {
                continue;
            }
            existing_pairs.add((cur, tgt));
            child_map.setdefault(cur, []).append((eid, tgt));
            child_state = TypedWalkerState(
                walker_type=wtype_name,
                nd=tgt,
                depth=state.depth + 1,
                incoming_edge=eid,
                children=[]
            );
            state.children.append(child_state);
            queue.append(child_state);
        }
    }
    return (ttg_root, visited_ids, child_map);
}

"""Build a prefetch list from TTG child_map.

BFS traversal of the child_map to produce an ordered list of UUIDs
(edges + targets) for cache prefetching.
"""
@ classmethod
impl JacTTGGenerator.get_prefetch_list(
    cls: type[JacTTGGenerator],
    start: UUID,
    ttg_children: dict[(UUID, list[tuple[(UUID, UUID)]])]
) -> list[UUID] {
    prefetch: list[UUID] = [];
    max_length = int(os.getenv('JAC_TTG_PREFETCH_LIMIT', '200'));
    seen: set[UUID] = `set();
    def _add(uid: UUID) -> None {
        if (uid not in seen) {
            seen.add(uid);
            prefetch.append(uid);
        }
    }
    queue: list[tuple[((UUID | None), UUID)]] = [(None, start)];
    while queue {
        (eid, nid) = queue.pop(0);
        if (eid is not None) {
            _add(eid);
        }
        _add(nid);
        children = ttg_children.get(nid, []);
        for (child_eid, child_nid) in children {
            if (child_nid not in seen) {
                queue.append((child_eid, child_nid));
            }
        }
        if (len(prefetch) >= max_length) {
            break;
        }
    }
    return prefetch[:max_length];
}
