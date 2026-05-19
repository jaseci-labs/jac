"""End-to-end tests for topology index using native Jac graph syntax.

Verifies correctness of the full pipeline: connect (+>) -> index update ->
query planning via edge ops (->) and filter comprehensions ([?:Type]) ->
correct results. Uses real Jac edge/filter syntax so regressions in the
compiler pipeline (exit_edge_ref_trailer, exit_filter_compr) are caught.
"""

import from typing { Any }
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

# Inheritance hierarchy used by the parent-type-query test below.
node BaseContent {
    has val: int = 0;
}

node PostNode(BaseContent) {}
node ArticleNode(BaseContent) {}

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

test "plan_query bypasses index when no hop is filtered" {
    import from jaclang.jac0core.archetype {
        ObjectSpatialPath,
        ObjectSpatialDestination,
        EdgeDir
    }
    import from jaclang.runtimelib.topo_utils { plan_query }

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

        # Fully unfiltered single-hop chain → planner must return None so
        # the runtime falls back to the natural edge-walk.
        unfiltered_path = ObjectSpatialPath(
            [r], [ObjectSpatialDestination(EdgeDir.OUT)]
        );
        assert plan_query(unfiltered_path) is None , (
            "plan_query should bypass TI for fully unfiltered chains"
        );

        # Edge-type filter alone is enough to engage the index.
        edge_filter = lambda e: Any : isinstance(e, EdgeX);
        edge_typed_path = ObjectSpatialPath(
            [r], [ObjectSpatialDestination(EdgeDir.OUT, edge_filter)]
        );
        assert plan_query(edge_typed_path) is not None , (
            "plan_query should engage TI when edge_type is filtered"
        );

        # Node-type filter alone also engages the index.
        node_filter = lambda n: Any : isinstance(n, TypeA);
        node_typed_path = ObjectSpatialPath(
            [r], [ObjectSpatialDestination(EdgeDir.OUT, None, node_filter)]
        );
        result = plan_query(node_typed_path);
        assert result is not None , "plan_query should engage TI when node_type is filtered";
        assert len(result) == 10 , f"expected 10 TypeA nodes, got {len(result)}";

        # Multi-hop fully unfiltered → still bypasses. The contract is "every
        # hop unfiltered", not just the first.
        two_hop_unfiltered = ObjectSpatialPath(
            [r],
            [
                ObjectSpatialDestination(EdgeDir.OUT),
                ObjectSpatialDestination(EdgeDir.OUT)
            ]
        );
        assert plan_query(two_hop_unfiltered) is None , (
            "two-hop fully unfiltered should bypass TI"
        );

        # Multi-hop with a filter on only the second hop → engages. A single
        # filtered hop anywhere in the chain is enough to want the index.
        mixed_two_hop = ObjectSpatialPath(
            [r],
            [
                ObjectSpatialDestination(EdgeDir.OUT),
                ObjectSpatialDestination(EdgeDir.OUT, None, node_filter)
            ]
        );
        assert plan_query(mixed_two_hop) is not None , (
            "two-hop with filter on second hop should engage TI"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "plan_query bails when a hop has predicates beyond type" {
    # `_filter_has_predicates` detects filter lambdas that do more than
    # `isinstance(i, T)` (attribute access, comparisons, etc). The index
    # can resolve those for the FINAL hop only — the runtime post-applies
    # that filter on the planned set. For non-final hops, plan_query
    # must bail and let the linear path evaluate the predicate directly.
    import from jaclang.jac0core.archetype {
        ObjectSpatialPath,
        ObjectSpatialDestination,
        EdgeDir
    }
    import from jaclang.runtimelib.topo_utils { plan_query }

    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            a = TypeA(val=i);
            r +>: EdgeX :+> a;
            a +>: EdgeY :+> TypeB(val=i * 10);
        }

        # `n.val > 5` introduces LOAD_ATTR + COMPARE_OP — _filter_has_predicates
        # returns True. On a single-hop (and therefore final) chain, plan_query
        # still engages: the runtime post-applies the predicate.
        pred_filter = lambda n: Any : isinstance(n, TypeA) and n.val > 5;
        single_hop_pred = ObjectSpatialPath(
            [r], [ObjectSpatialDestination(EdgeDir.OUT, None, pred_filter)]
        );
        assert plan_query(single_hop_pred) is not None , (
            "predicate on the FINAL hop should still engage TI"
        );

        # Same predicate on a non-final hop in a 2-hop chain → bail.
        two_hop_pred_first = ObjectSpatialPath(
            [r],
            [
                ObjectSpatialDestination(EdgeDir.OUT, None, pred_filter),
                ObjectSpatialDestination(EdgeDir.OUT)
            ]
        );
        assert plan_query(two_hop_pred_first) is None , (
            "predicate on a non-final hop should bail to linear path"
        );

        # End-to-end correctness: predicate on final hop produces the right
        # subset, regardless of which path the runtime took.
        result = [r->:EdgeX:->[?:TypeA, val>5]];
        assert sorted([n.val for n in result]) == [6, 7, 8, 9];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}

test "parent-type filter returns all subtype instances" {
    # BUG: pre-PR 5784 main only ever indexed concrete type names. The hooks
    # called `_type_name(node.archetype)` which is just `type(obj).__name__`,
    # and resolve_chain matched targets by strict `node_table[lid][1] ==
    # ntid`. So `[r->:EdgeX:->[?:BaseContent]]` against a graph containing
    # only PostNode and ArticleNode instances returned the empty set --
    # parent-type queries silently dropped every subtype instance.
    #
    # The fix indexes each target under every ancestor in its MRO at
    # edge-creation time. This test pins the e2e behavior so a regression
    # in the MRO fan-out path can't silently return empty sets again.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(5) {
            r +>: EdgeX :+> PostNode(val=i);
        }
        for i in range(5) {
            r +>: EdgeX :+> ArticleNode(val=100 + i);
        }

        # Parent-type filter: must return ALL 10 (5 PostNode + 5 ArticleNode).
        all_subtypes = [r->:EdgeX:->[?:BaseContent]];
        assert len(all_subtypes) == 10 , (
            f"BaseContent parent query should return all 10 subtype instances, got {len(
                all_subtypes
            )}"
        );
        vals = sorted([n.val for n in all_subtypes]);
        assert vals == [0, 1, 2, 3, 4, 100, 101, 102, 103, 104];

        # Concrete-subtype filter still narrows to exactly its own type.
        only_posts = [r->:EdgeX:->[?:PostNode]];
        assert len(only_posts) == 5;
        assert sorted([n.val for n in only_posts]) == [0, 1, 2, 3, 4];

        # Cross-check with the index disabled in the same context — both paths
        # must produce identical results, proving the MRO-aware index doesn't
        # invent matches that the natural walk wouldn't return.
        cfg.run.topology_index = False;
        set_config(cfg);
        nat_all = sorted([n.val for n in [r->:EdgeX:->[?:BaseContent]]]);
        nat_posts = sorted([n.val for n in [r->:EdgeX:->[?:PostNode]]]);
        assert nat_all == vals;
        assert nat_posts == [0, 1, 2, 3, 4];
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
