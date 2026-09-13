"""Lifecycle of the sv driver's slice of the process-global osp_graph store.

Every `_SvStore` carries a region id, every row it mints is tagged with that
region, and `TieredMemory.close` retracts the region (`osp_region_died`) and
recycles the store's anchor handles. These tests pin the two consequences:
a long-running process serving many contexts returns to baseline occupancy
after each close (no monotonic growth of rows or of the handle table), and
retracting one context's region leaves another context's live topology and
anchor identity untouched. Unowned graphs instead follow Python reachability:
the handle table must neither retain an unreachable component nor collect a
component that is still reachable through one of its nodes.
"""

import jaclang.runtime.osp_graph as _g;
import jaclang.runtime.osp_graph_sv as _sv;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from weakref { ReferenceType, ref }
import from jaclang.runtime.archetype { EdgeAnchor, NodeAnchor }
import from jaclang.runtime.osp_graph_sv { handle_of, sv_conn, sv_live_edges }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

def _as_any(v: any) -> any {
    return v;
}

node LifeNode {
    has label: str = "";
}

edge LifeEdge {}

edge LifeHeavyEdge {
    has weight: int = 42;
}

def _unowned_pair -> tuple[LifeNode, list[ReferenceType[LifeNode | LifeHeavyEdge]]] {
    a = LifeNode(label="transient.src");
    b = LifeNode(label="transient.tgt");
    rel = LifeHeavyEdge();
    a +>:rel:+> b;
    return (a, [ref(a), ref(b), ref(rel)]);
}

test "unowned graph lifetime follows its reachable topology" {
    import gc;
    import from jaclang.runtime.runtime { _request_context }
    orig_ctx = JacRuntime.exec_ctx;
    token = _request_context.set(None);
    JacRuntime.exec_ctx = None;
    try {
        gc.collect();
        rows = _live_rows();
        handles = len(_sv._obj_of_h) - len(_sv._h_free);
        keys = len(_sv._fallback.h_of_key);
        head: LifeNode | None = None;
        for i in range(3) {
            (head, refs) = _unowned_pair();
            gc.collect();
            assert len([head-->]) == 1 , "a reachable graph lost its target";
            assert all(r() is not None for r in refs);
            head = None;
            gc.collect();
            assert all(r() is None for r in refs) , "the graph registry retained an unreachable component";
            assert _live_rows() == rows , "unreachable graph rows were not retired";
            assert len(_sv._obj_of_h) - len(_sv._h_free) == handles;
            assert len(_sv._fallback.h_of_key) == keys;
        }
    } finally {
        JacRuntime.exec_ctx = orig_ctx;
        _request_context.reset(token);
    }
}

test "unregistered graph reads do not create handles" {
    import from jaclang.runtime.runtime { _request_context }
    orig_ctx = JacRuntime.exec_ctx;
    token = _request_context.set(None);
    JacRuntime.exec_ctx = None;
    try {
        a = LifeNode(label="isolated").__jac__;
        handles = len(_sv._obj_of_h) - len(_sv._h_free);
        keys = len(_sv._fallback.h_of_key);
        assert sv_live_edges(a, 3, None, False) == [];
        assert sv_live_edges(a, 3, LifeEdge, True) == [];
        assert len(_sv._fallback.h_of_key) == keys;
        assert len(_sv._obj_of_h) - len(_sv._h_free) == handles;
    } finally {
        JacRuntime.exec_ctx = orig_ctx;
        _request_context.reset(token);
    }
}

test "transient graphs are collectable inside an execution context" {
    import gc;
    orig_ctx = JacRuntime.exec_ctx;
    with TemporaryDirectory() as proj {
        ctx = _mk_ctx(proj, "transient");
        JacRuntime.exec_ctx = ctx;
        try {
            gc.collect();
            rows = _live_rows();
            handles = len(_sv._obj_of_h) - len(_sv._h_free);
            (head, refs) = _unowned_pair();
            gc.collect();
            assert len([head-->]) == 1;
            del head;
            gc.collect();
            assert all(r() is None for r in refs) , "the context registry retained a transient component";
            assert _live_rows() == rows;
            assert len(_sv._obj_of_h) - len(_sv._h_free) == handles;
        } finally {
            ctx.close();
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}

test "unowned handles survive identity promotion and retire the promoted key" {
    import gc;
    import from jaclang.runtime.runtime { _request_context }
    orig_ctx = JacRuntime.exec_ctx;
    token = _request_context.set(None);
    JacRuntime.exec_ctx = None;
    try {
        gc.collect();
        keys = len(_sv._fallback.h_of_key);
        handles = len(_sv._obj_of_h) - len(_sv._h_free);
        a = LifeNode().__jac__;
        h = handle_of(a);
        identity = id(a);
        promoted = a.ensure_id();
        assert handle_of(a) == h;
        assert identity not in _sv._fallback.h_of_key;
        assert _sv._fallback.h_of_key[promoted] == h;
        assert _sv.obj_of(h) is a;
        held = ref(a);
        del a;
        gc.collect();
        assert held() is None;
        assert promoted not in _sv._fallback.h_of_key;
        assert _sv.obj_of(h) is None;
        assert len(_sv._fallback.h_of_key) == keys;
        assert len(_sv._obj_of_h) - len(_sv._h_free) == handles;
    } finally {
        JacRuntime.exec_ctx = orig_ctx;
        _request_context.reset(token);
    }
}

def _live_rows -> int {
    return len(_g.DEFAULT_GRAPH.rows) - len(_g.DEFAULT_GRAPH.free_rows);
}

def _mk_ctx(dirpath: str, name: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=dirpath, full_target_path=str(Path(dirpath) / f"{name}.jac")
    );
}

def _connect_pair(mem: any, label: str) -> tuple[NodeAnchor, NodeAnchor, EdgeAnchor] {
    a = LifeNode(label=f"{label}.src").__jac__;
    b = LifeNode(label=f"{label}.tgt").__jac__;
    e = EdgeAnchor(
        archetype=_as_any(LifeEdge()), source=a, target=b, is_undirected=False
    );
    sv_conn(a, b, e, False, mem);
    return (a, b, e);
}

test "closing a context retracts its rows and recycles its handles" {
    with TemporaryDirectory() as proj {
        orig_ctx = JacRuntime.exec_ctx;
        try {
            cap_rows = -1;
            cap_handles = -1;
            for i in range(5) {
                pre_rows = _live_rows();
                ctx = _mk_ctx(proj, f"leak_{i}");
                pairs: list[tuple[NodeAnchor, NodeAnchor, EdgeAnchor]] = [];
                for j in range(8) {
                    pairs.append(_connect_pair(ctx.mem, f"leak_{i}_{j}"));
                }
                assert _live_rows() == pre_rows + 8;
                ctx.close();
                assert _live_rows() == pre_rows , "close left rows behind";
                if i == 0 {
                    cap_rows = len(_g.DEFAULT_GRAPH.rows);
                    cap_handles = len(_sv._obj_of_h);
                } else {
                    assert len(_g.DEFAULT_GRAPH.rows) == cap_rows , "row table grew across contexts";
                    assert len(_sv._obj_of_h) == cap_handles , "handle table grew across contexts";
                }
            }
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}

test "closing one context leaves another context's live topology intact" {
    with TemporaryDirectory() as proj {
        orig_ctx = JacRuntime.exec_ctx;
        try {
            ctx_a = _mk_ctx(proj, "iso_a");
            ctx_b = _mk_ctx(proj, "iso_b");
            (a1, a2, _a_edge) = _connect_pair(ctx_a.mem, "a");
            (b1, b2, _b_edge) = _connect_pair(ctx_b.mem, "b");
            h_a1 = handle_of(a1, ctx_a.mem);
            assert len(sv_live_edges(b1, 3, None, False, ctx_b.mem)) == 1;

            ctx_a.close();

            assert _g.osp_refs(h_a1, 3, -1, 0) == [] , "closed context's rows survived";
            outs = sv_live_edges(b1, 3, None, False, ctx_b.mem);
            assert len(outs) == 1 , "survivor context lost topology";
            assert outs[0] is b2 , "survivor traversal lost anchor identity";

            (c1, c2, _c_edge) = _connect_pair(ctx_b.mem, "c");
            assert len(sv_live_edges(c1, 3, None, False, ctx_b.mem)) == 1;
            assert len(sv_live_edges(b1, 3, None, False, ctx_b.mem)) == 1;

            ctx_b.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
