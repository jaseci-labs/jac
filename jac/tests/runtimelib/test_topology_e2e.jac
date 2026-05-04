"""End-to-end tests for topology index using native Jac graph syntax.

Verifies correctness of the full pipeline: connect (+>) -> index update ->
query planning via edge ops (->) and filter comprehensions ([?:Type]) ->
correct results. Uses real Jac edge/filter syntax so regressions in the
compiler pipeline (exit_edge_ref_trailer, exit_filter_compr) are caught.
"""

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }

node TypeA {
    has val: int = 0;
}

node TypeB {
    has val: int = 0;
}

edge EdgeX {}
edge EdgeY {}

# Edge carrying its own attribute, for tests that exercise typed-edge filter
# clauses like `:weight>5:` (compares against edge state, not destination).
edge Weighted {
    has weight: int = 0;
}

test "index type-filtered query returns correct results" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;

        for i in range(10) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        for i in range(90) {
            r +>: EdgeX :+> TypeB(val=i);
        }

        # Type-filtered: only TypeA via EdgeX
        result = [r->:EdgeX:->[?:TypeA]];
        assert len(result) == 10 , f"Expected 10 TypeA, got {len(result)}";
        assert sorted([n.val for n in result]) == list(range(10));

        # Unfiltered: all 100 nodes
        result_all = [r->:EdgeX:->];
        assert len(result_all) == 100 , f"Expected 100 total, got {len(result_all)}";
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "index results match non-indexed results in same context" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(20) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        for i in range(80) {
            r +>: EdgeX :+> TypeB(val=i);
        }

        # With index (default): type-filtered
        on_result = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]]]);

        # Disable index and re-query in same context
        cfg.run.topology_index = False;
        set_config(cfg);
        off_result = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]]]);

        assert off_result == on_result , f"Results differ: off={off_result} on={on_result}";
        assert len(off_result) == 20;
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "index returns empty for non-matching edge type" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            r +>: EdgeX :+> TypeA(val=i);
        }

        # EdgeY not in graph — should be empty
        result = [r->:EdgeY:->[?:TypeA]];
        assert len(result) == 0 , f"Expected 0, got {len(result)}";
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "post-hoc filter fused with edge-op produces same results" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        for i in range(90) {
            r +>: EdgeX :+> TypeB(val=i);
        }

        # Inline filter (already optimized)
        inline = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]]]);

        # Post-hoc filter (should be fused and produce same results)
        posthoc = sorted([n.val for n in [r->:EdgeX:->][?:TypeA]]);

        assert inline == posthoc , f"Inline vs post-hoc differ: {inline} vs {posthoc}";
        assert len(inline) == 10;
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "nested post-hoc filter as origin of outer edge-op" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        # root -> TypeA via EdgeX, TypeA -> TypeB via EdgeY
        for i in range(5) {
            a = TypeA(val=i);
            r +>: EdgeX :+> a;
            a +>: EdgeY :+> TypeB(val=i * 10);
        }
        # root -> TypeB via EdgeX (decoys)
        for i in range(20) {
            r +>: EdgeX :+> TypeB(val=100 + i);
        }

        # Inline multi-hop: get TypeB behind TypeA
        inline = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]->:EdgeY:->[?:TypeB]]]);

        # Nested: post-hoc filter TypeA, then use as origin for EdgeY hop
        type_a_nodes = [r->:EdgeX:->][?:TypeA];
        nested = sorted([n.val for n in [type_a_nodes->:EdgeY:->[?:TypeB]]]);

        assert inline == nested , f"Inline vs nested differ: {inline} vs {nested}";
        assert inline == [0, 10, 20, 30, 40];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "index built on root with null root field" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        r +>: EdgeX :+> TypeA(val=42);

        idx = r.__jac__.get_topology_index();
        assert len(idx) > 0 , "Index should have edges";
        assert len(idx.node_table) == 2 , "Index should have root + TypeA";
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "typed-edge filter compares against edge attributes apply at runtime" {
    # BUG: the topology-index fast path (plan_query) extracts only
    # type names from filter lambdas and feeds them to the index, which
    # silently drops any predicate clause on the edge attributes
    # themselves -- e.g. `[r->:Weighted:weight>=5:->]` returns ALL
    # Weighted-connected nodes regardless of weight.
    #
    # Reproduces the docs example
    # `[root()->:Scheduled:priority>=3:->]` from the AI day planner
    # tutorial Part 2 ("Advanced: Custom Edges"). The parser fix in
    # PR #5799 made the syntax legal; this test pins the runtime
    # semantics so the fast path can't silently regress them.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        # Three nodes connected via Weighted edges with weights 1, 5, 10.
        # Predicate `weight>=5` should keep weights 5 and 10 (vals 20, 30).
        r +>: Weighted(weight=1) :+> TypeA(val=10);
        r +>: Weighted(weight=5) :+> TypeA(val=20);
        r +>: Weighted(weight=10) :+> TypeA(val=30);

        heavy = sorted([n.val for n in [r->:Weighted:weight>=5:->]]);
        assert heavy == [20, 30] , (
            f"typed-edge predicate `:weight>=5:` must filter at runtime; "
            f"got {heavy}, expected [20, 30]"
        );

        # Sanity: without the predicate, all three connect.
        all_w = sorted([n.val for n in [r->:Weighted:->]]);
        assert all_w == [10, 20, 30] , (
            f"baseline (no predicate): expected [10, 20, 30], got {all_w}"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "non-final node predicate in multi-hop chain applies at runtime" {
    # Companion to the test above: even when the predicate is on a
    # NODE (not an edge), the fast path's post-filter only runs on the
    # FINAL destination. Predicates on intermediate hops were silently
    # dropped for the same reason -- only type names were forwarded.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        # Build r --EdgeX--> TypeA(val=v) --EdgeY--> TypeB(val=v*10)
        # for v in {1, 5, 10}. A two-hop query
        # `[r->:EdgeX:->[?:TypeA, val>=5]->:EdgeY:->[?:TypeB]]` should
        # only follow the v>=5 chains, yielding TypeB vals [50, 100].
        for v in [1, 5, 10] {
            mid = r +>: EdgeX :+> TypeA(val=v);
            mid[0] +>: EdgeY :+> TypeB(val=v * 10);
        }

        leaves = sorted(
            [n.val for n in [r->:EdgeX:->[?:TypeA, val>=5]->:EdgeY:->[?:TypeB]]]
        );
        assert leaves == [50, 100] , (
            f"intermediate-hop predicate `val>=5` must filter; "
            f"got {leaves}, expected [50, 100]"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}
