"""Pin the QueryPlan -> MongoDB filter translation for field predicates.

The planner converts filter-comprehension specs into cross-backend operator
dicts (`{'val': {'$gt': 5}}`); `_plan_to_mongo_filter` must pass them through
verbatim under the `data.archetype.` prefix alongside type and id narrowing.
Pure unit tests — no container needed.
"""

import from jac_scale.memory_hierarchy { _plan_to_mongo_filter }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from uuid { uuid4 }


test "field predicates land under data.archetype with type filter" {
    plan = QueryPlan(
        node_type_final="User",
        field_predicates={"age": {"$lt": 28}, "status": {"$eq": "active"}}
    );
    (filt, skip_n, limit_n) = _plan_to_mongo_filter(plan);
    assert filt["arch_type"] == "User";
    assert filt["type"] == "NodeAnchor";
    assert filt["data.archetype.age"] == {"$lt": 28};
    assert filt["data.archetype.status"] == {"$eq": "active"};
    assert skip_n == 0 and limit_n is None;
}

test "field predicates compose with id_in narrowing" {
    ids = {uuid4(), uuid4()};
    plan = QueryPlan(id_in=ids, field_predicates={"val": {"$gte": 1, "$lt": 9}});
    (filt, _, _) = _plan_to_mongo_filter(plan);
    assert sorted(filt["_id"]["$in"]) == sorted([str(u) for u in ids]);
    assert filt["data.archetype.val"] == {"$gte": 1, "$lt": 9};
    # No type on the plan -> no arch_type clause.
    assert "arch_type" not in filt;
}
