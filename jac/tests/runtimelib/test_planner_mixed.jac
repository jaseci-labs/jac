"""Focused tests for the planner's mixed-strategy post_filter contract.

The mixed strategy (topology narrows the chain, the backend materializes the
candidate set via `id_in` + field predicates) applies the destination's
`post_filter` ABOVE the backend result. That post_filter is the node-filter
callable, which receives an *archetype* — exactly like the pure-pushdown path.
A regression that handed it the raw Anchor would make `isinstance(i, T)` fail
and silently drop every row.

These tests drive `_execute_mixed` directly with a fake backend so they need
no storage container and run in-process.
"""

import from jaclang.runtimelib.planner { _execute_mixed }
import from jaclang.runtimelib.query_plan { QueryPlan, FieldPredicate }
import from uuid { uuid4 }


obj _FakeArch {
    has val: int;
}


obj _FakeAnchor {
    has archetype: _FakeArch;
}


"""Backend that declares field+id_in pushdown and yields anchors verbatim."""
obj _FakeBackend {
    has yielded: list[_FakeAnchor];

    def capabilities -> set[str] {
        return {'field_pushdown','id_in'};
    }

    def execute_plan(plan: QueryPlan) -> list[_FakeAnchor] {
        return self.yielded;
    }
}


test "mixed strategy applies post_filter to the archetype, not the anchor" {
    anchors = [_FakeAnchor(archetype=_FakeArch(val=v)) for v in [1, 2, 3, 4]];
    backend = _FakeBackend(yielded=anchors);

    # post_filter is a node-filter: it receives an archetype and reads `.val`.
    seen_types: list = [];
    def keep_even(item: _FakeArch) -> bool {
        seen_types.append(type(item).__name__);
        return item.val % 2 == 0;
    }
    plan = QueryPlan(
        root_id=uuid4(),
        field_predicates={'val': [FieldPredicate(op='gt', value=0)]},
        post_filter=keep_even
    );
    result = _execute_mixed(backend, plan, {a.archetype for a in anchors});

    # The filter must have been handed _FakeArch instances (archetypes).
    assert seen_types == ['_FakeArch'] * 4 , (
        f"post_filter must receive archetypes; saw {seen_types}"
    );
    # And the filtering must actually take effect (evens kept).
    kept = sorted([a.archetype.val for a in result]);
    assert kept == [2, 4] , f"expected evens [2, 4], got {kept}";
}
