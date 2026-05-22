"""QueryPlan implementation."""

"""True when the plan describes a no-op: no chain, no predicates, no narrowing,
no type filter. The planner treats trivial plans as "load all anchors" and
typically refuses to execute them — callers should use `query()` directly.
"""
impl QueryPlan.is_trivial -> bool {
    return (
        not self.chain
        and not self.field_predicates
        and self.id_in is None
        and self.node_type_final is None
    );
}


"""The set of capability strings a backend must declare to handle this plan
without help from the planner's floor. Used by the planner to pick a routing
strategy.

A backend that declares a strict superset of `plan.needs()` can take the plan
as-is. Otherwise the planner composes: it strips needs the backend can't meet
(applying them above), then hands down the reduced plan.
"""
impl QueryPlan.needs -> set[str] {
    needs: set[str] = set();
    if self.node_type_final is not None
    or any(h.edge_type is not None or h.node_type is not None for h in self.chain) {
        needs.add('type_pushdown');
    }
    if self.field_predicates {
        needs.add('field_pushdown');
    }
    if self.id_in is not None {
        needs.add('id_in');
    }
    if self.slc is not None {
        needs.add('slice');
    }
    return needs;
}


"""Debug-friendly representation used by JAC_QUERY_TRACE."""
impl QueryPlan.repr -> str {
    parts: list[str] = [];
    if self.root_id is not None {
        parts.append(f"root={str(self.root_id)[:8]}");
    }
    if self.chain {
        hops = [
            f"[{h.edge_type or '*'}-{h.direction}->{h.node_type or '*'}]"
            for h in self.chain
        ];
        parts.append(f"chain={''.join(hops)}");
    }
    if self.node_type_final is not None {
        parts.append(f"type={self.node_type_final}");
    }
    if self.field_predicates {
        parts.append(f"fields={self.field_predicates}");
    }
    if self.id_in is not None {
        parts.append(f"id_in=|{len(self.id_in)}|");
    }
    if self.slc is not None {
        parts.append(f"slice={self.slc.start}:{self.slc.stop}:{self.slc.step}");
    }
    return f"QueryPlan({' '.join(parts) or 'trivial'})";
}
