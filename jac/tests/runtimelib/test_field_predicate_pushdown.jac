"""Tests for value-predicate pushdown from filter comprehensions.

Covers the full chain that turns `[-->][?:T, val > 5]` into a backend-side
field query:

  codegen tags the filter lambda via `filter_spec` with `(field, op, value)`
  triples -> the planner converts the spec into cross-backend operator dicts
  on `QueryPlan.field_predicates` -> `execute_path` routes through the hybrid
  executor, evaluating L1-resident candidates in Python (fresh) and pushing
  `_id IN (cold) AND predicates` to a capable backend.

Each test uses its own node/edge types so results are isolated from graph
state accumulated by other tests sharing the session DB.
"""

import os;
import tempfile;
import from tempfile { NamedTemporaryFile }
import from jaclang.jac0core.jaclib { filter_spec }
import from jaclang.jac0core.archetype { ObjectSpatialPath }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.planner {
    _build_plan_from_path,
    _predicates_to_field_filters,
    execute_path
}
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.project.config { JacConfig, set_config }

glob _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_field_pred_");

node PredTypeA {
    has val: int = 0;
}

node PredTypeB {
    has val: int = 0;
}

node PredTypeC {
    has val: int = 0;
}

edge PredEdge {}
edge PredEdgeC {}


"""Compile inline Jac source and return the module (for gen.py asserts)."""
def _compile_inline(code: str) -> object {
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        mod = JacProgram().compile(f.name);
        os.unlink(f.name);
        return mod;
    }
}


test "filter_spec tags the callable and preserves behavior" {
    spec = (("val", ">", 5), );
    f = filter_spec(lambda i: any : i.val > 5, spec);
    assert f.__jac_predicates__ == spec;
    assert f(PredTypeA(val=6));
    assert not f(PredTypeA(val=5));
}

test "codegen attaches predicate spec to filter comprehensions" {
    mod = _compile_inline(
        "node T { has val: int = 0; }\n" "with entry { x = [root-->][?val > 5]; }\n"
    );
    py = mod.gen.py;
    assert "filter_spec" in py , f"expected filter_spec wrapper in:\n{py}";
    assert "'val', '>', 5" in py , f"expected spec triple in:\n{py}";
}

test "codegen hoists computed comparators into shared params" {
    # Non-constant comparators are lifted into an immediately-invoked lambda
    # parameter: the expression resolves once at query time and the spec and
    # filter lambda share the resolved value.
    mod = _compile_inline(
        "node T { has val: int = 0; }\n"
        "def limit -> int { return 5; }\n"
        "with entry { x = [root-->][?val > limit()]; }\n"
    );
    py = mod.gen.py;
    assert "filter_spec" in py , f"expected filter_spec wrapper in:\n{py}";
    assert "_jfs0" in py , f"expected hoisted comparator param in:\n{py}";
    assert "'val', '>', _jfs0" in py , f"expected spec to share the param in:\n{py}";
}

glob _limit_calls: dict = {"n": 0};

def _counted_limit -> int {
    _limit_calls["n"] += 1;
    return 15;
}

test "computed comparator resolves once at query time" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            r +>:PredEdgeC:+> PredTypeC(val=i + 10);
        }
        _limit_calls["n"] = 0;
        result = [r->:PredEdgeC:->[?:PredTypeC, val>_counted_limit()]];
        vals = sorted([n.val for n in result]);
        assert vals == [16, 17, 18, 19] , f"got {vals}";
        assert _limit_calls["n"] == 1 , (
            f"comparator must evaluate exactly once, got {_limit_calls['n']}"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "predicate spec converts to backend field filters" {
    # Plain operator mapping.
    assert _predicates_to_field_filters((("val", ">", 5), )) == {"val": {"$gt": 5}};
    assert _predicates_to_field_filters((("name", "==", "a"), )) == {
        "name": {"$eq": "a"}
    };
    # Two ops on the same field merge into one operator dict.
    assert _predicates_to_field_filters((("val", ">=", 1), ("val", "<", 9))) == {
        "val": {"$gte": 1, "$lt": 9}
    };
    # Duplicate op on the same field keeps the tighter bound (max for $gt/$gte,
    # min for $lt/$lte) so the backend filters more; lambda enforces the rest.
    assert _predicates_to_field_filters((("val", ">", 1), ("val", ">", 5))) == {
        "val": {"$gt": 5}
    };
    assert _predicates_to_field_filters((("val", "<", 9), ("val", "<", 4))) == {
        "val": {"$lt": 4}
    };
    # Membership ops need a literal collection of plain scalars.
    assert _predicates_to_field_filters((("tag", "in", ["a", "b"]), )) == {
        "tag": {"$in": ["a", "b"]}
    };
    assert _predicates_to_field_filters((("tag", "in", [object()]), )) == {};
    # `is` / `is not` push only against None.
    assert _predicates_to_field_filters((("ref", "is", None), )) == {
        "ref": {"$eq": None}
    };
    assert _predicates_to_field_filters((("ref", "is", "x"), )) == {};
    # Range ops reject None and bool (backend ordering diverges from Python).
    assert _predicates_to_field_filters((("val", "<", None), )) == {};
    assert _predicates_to_field_filters((("flag", "<", True), )) == {};
    # Non-scalar values never push.
    assert _predicates_to_field_filters((("val", "==", object()), )) == {};
    # Malformed specs are ignored wholesale.
    assert _predicates_to_field_filters(None) == {};
    assert _predicates_to_field_filters((("val", ">"), )) == {};
}

test "planner lifts spec onto the query plan" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        r +>:PredEdge:+> PredTypeA(val=1);
        filt = filter_spec(
            lambda i: any : (isinstance(i, PredTypeA) and i.val > 5),
            (("val", ">", 5), )
        );
        path = ObjectSpatialPath(r, None).edge_out(nd=filt);
        plan = _build_plan_from_path(ctx.mem, path, None);
        assert plan is not None , "predicate filter must still produce a plan";
        assert plan.field_predicates == {"val": {"$gt": 5}} , (
            f"expected converted predicates, got {plan.field_predicates}"
        );
        assert plan.post_filter is not None , (
            "lambda must stay on as post_filter — pushdown only narrows"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

# Stand-in L3 with native field pushdown, instrumented to capture the plans
# the planner hands down. Applies `$gt` the way a real backend would, over
# its own (possibly stale) store.
obj _StubL3 {
    has store: dict = {},
        plans: list = [];

    def capabilities -> set[str] {
        return {"type_pushdown", "field_pushdown", "id_in"};
    }

    def execute_plan(plan: any) -> list {
        self.plans.append(plan);
        gt = plan.field_predicates.get("val", {}).get("$gt");
        out: list = [];
        for (id, anchor) in self.store.items() {
            if plan.id_in is not None and id not in plan.id_in {
                continue;
            }
            if gt is not None and not (anchor.archetype.val > gt) {
                continue;
            }
            out.append(anchor);
        }
        return out;
    }

    def get(id: any) -> any {
        return self.store.get(id);
    }

    def sync { }
    def commit(anchor: any = None) { }
    def close { }
}

test "hybrid splits L1-resident and cold candidates" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    orig_l3 = ctx.mem.l3;
    try {
        r = root;
        nodes: list = [];
        for i in range(10) {
            n = PredTypeB(val=i);
            r +>:PredEdge:+> n;
            nodes.append(n);
        }
        # Evict even-val anchors from L1 into a stub L3 — they become the
        # "cold" partition the planner must query through the backend.
        stub = _StubL3();
        cold_ids: set = set();
        for n in nodes {
            anchor = n.__jac__;
            if n.val % 2 == 0 {
                stub.store[anchor.id] = anchor;
                cold_ids.add(anchor.id);
                ctx.mem.__mem__.pop(anchor.id);
            }
        }
        ctx.mem.l3 = stub;
        # Freshness: an L1-resident anchor mutated this session must be
        # judged on its live value, not whatever a backend last synced.
        nodes[3].val = 100;

        filt = filter_spec(
            lambda i: any : (isinstance(i, PredTypeB) and i.val > 5),
            (("val", ">", 5), )
        );
        path = ObjectSpatialPath(r, None).edge_out(nd=filt);
        result = execute_path(ctx.mem, path);
        assert result is not None , "hybrid route must engage, not bail";
        vals = sorted([a.archetype.val for a in result]);
        # resident odd vals {1, 100, 5, 7, 9} -> 7, 9, 100 pass;
        # cold even vals {0, 2, 4, 6, 8} -> stub returns 6, 8.
        assert vals == [6, 7, 8, 9, 100] , f"got {vals}";

        assert len(stub.plans) == 1 , "cold partition must hit the backend once";
        cold_plan = stub.plans[0];
        assert cold_plan.field_predicates == {"val": {"$gt": 5}};
        assert cold_plan.id_in == cold_ids , (
            "backend must only be asked about non-resident candidates"
        );
    } finally {
        ctx.mem.l3 = orig_l3;
        ctx.close();
        set_config(JacConfig());
    }
}

test "value predicate comprehension filters e2e" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            r +>:PredEdge:+> PredTypeA(val=i + 10);
        }
        result = [r->:PredEdge:->[?:PredTypeA, val>15]];
        vals = sorted([n.val for n in result]);
        assert vals == [16, 17, 18, 19] , f"got {vals}";
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}
