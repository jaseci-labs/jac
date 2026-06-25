"""Per-hop resolver tests — pins down behavior that's specific to the
per-hop fold structure introduced by `jaclang.runtimelib.resolver`.

These complement `test_topology_e2e.jac` (which guards execute_path-level
parity) by exercising the resolver's per-hop entry points directly and by
locking down the bail boundary that future PRs will widen."""

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.runtimelib.resolver { resolve_path_anchors }
import from jaclang.jac0core.archetype {
    ObjectSpatialPath,
    ObjectSpatialDestination,
    EdgeDir
}


node R1Hop {
    has val: int = 0;
}

node R2Hop {
    has val: int = 0;
}

node R3Hop {
    has val: int = 0;
}

edge Hop1 {}
edge Hop2 {}
edge Hop3 {}


test "3-hop type-filtered chain resolves via the per-hop fold" {
    # A purely type-filtered 3-hop chain must walk all three hops on the
    # index and return the leaf set correctly. This is the happy-path the
    # per-hop fold replaces today's `plan_chain` set-narrowing branch with.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        # root -> R1Hop -> R2Hop -> R3Hop  (5 leaves)
        for i in range(5) {
            a = R1Hop(val=i);
            r +>:Hop1:+> a;
            b = R2Hop(val=i * 10);
            a +>:Hop2:+> b;
            b +>:Hop3:+> R3Hop(val=i * 100);
        }
        leaves = [r->:Hop1:->->:Hop2:->->:Hop3:->[?:R3Hop]];
        assert len(leaves) == 5 , f"expected 5 leaves, got {len(leaves)}";
        assert sorted([n.val for n in leaves]) == [0, 100, 200, 300, 400];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}


test "single-hop slice on last hop applies ordered+sliced result" {
    # Single-hop with a slice exercises `resolve_hop`'s ordered branch — the
    # last hop receives a non-None `slc` and `resolve_chain_ordered` is the
    # only path that produces it. Pins down the use_ordered branch in
    # resolve_path_anchors.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(20) {
            r +>:Hop1:+> R1Hop(val=i);
        }
        sliced = [r->:Hop1:->[?:R1Hop]][0:5];
        assert len(sliced) == 5 , f"expected slice of 5, got {len(sliced)}";
        # Canonical edge-insertion order means the first 5 are vals 0..4.
        assert sorted([n.val for n in sliced]) == [0, 1, 2, 3, 4];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}


test "predicate on non-final hop resolves via per-hop walk fallback" {
    # The core promise of the per-hop fold: an awkward hop (predicate filter
    # that the index can't apply) falls back to `_hop_via_walk` locally,
    # while the *other* hops still use the index. No global bail.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            a = R1Hop(val=i);
            r +>:Hop1:+> a;
            a +>:Hop2:+> R2Hop(val=i * 10);
        }
        # `n.val > 5` introduces LOAD_ATTR + COMPARE_OP — this hop walks; the
        # second hop still uses the index.
        pred_filter = lambda n: any : isinstance(n, R1Hop) and n.val > 5;
        path = ObjectSpatialPath(
            [r],
            [
                ObjectSpatialDestination(EdgeDir.OUT, None, pred_filter),
                ObjectSpatialDestination(EdgeDir.OUT)
            ]
        );
        ctx_mem = JacRuntime.get_context().mem;
        anchors = resolve_path_anchors(ctx_mem, path);
        vals = sorted([a.archetype.val for a in anchors]);
        assert vals == [60, 70, 80, 90] , (
            f"resolver must handle predicate-on-non-final-hop via per-hop "
            f"walk fallback, got {vals!r}"
        );
        # End-to-end via `refs()` produces the same answer.
        leaves = [r->:Hop1:->[?:R1Hop, val>5]->:Hop2:->[?:R2Hop]];
        assert sorted([n.val for n in leaves]) == [60, 70, 80, 90];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}
