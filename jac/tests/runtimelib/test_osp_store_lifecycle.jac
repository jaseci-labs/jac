"""Lifecycle of the sv driver's slice of the process-global osp_graph store.

Every `_SvStore` carries a region id, every row it mints is tagged with that
region, and `TieredMemory.close` retracts the region (`osp_region_died`) and
recycles the store's anchor handles. These tests pin the two consequences:
a long-running process serving many contexts returns to baseline occupancy
after each close (no monotonic growth of rows or of the handle table), and
retracting one context's region leaves another context's live topology and
anchor identity untouched.
"""

import jaclang.jac0core.osp_graph as _g;
import jaclang.jac0core.osp_graph_sv as _sv;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor }
import from jaclang.jac0core.osp_graph_sv { handle_of, sv_conn, sv_live_edges }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }

node LifeNode {
    has label: str = "";
}

edge LifeEdge {}

def _live_rows -> int {
    return len(_g._r_src) - len(_g._row_free);
}

def _mk_ctx(dirpath: str, name: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=dirpath, full_target_path=str(Path(dirpath) / f"{name}.jac")
    );
}

def _connect_pair(mem: any, label: str) -> tuple {
    a = LifeNode(label=f"{label}.src").__jac__;
    b = LifeNode(label=f"{label}.tgt").__jac__;
    e = EdgeAnchor(archetype=LifeEdge(), source=a, target=b, is_undirected=False);
    sv_conn(a, b, e, False, mem);
    return (a, b);
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
                for j in range(8) {
                    _connect_pair(ctx.mem, f"leak_{i}_{j}");
                }
                assert _live_rows() == pre_rows + 8;
                ctx.close();
                assert _live_rows() == pre_rows , "close left rows behind";
                if i == 0 {
                    cap_rows = len(_g._r_src);
                    cap_handles = len(_sv._obj_of_h);
                } else {
                    assert len(_g._r_src) == cap_rows , "row table grew across contexts";
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
            (a1, a2) = _connect_pair(ctx_a.mem, "a");
            (b1, b2) = _connect_pair(ctx_b.mem, "b");
            h_a1 = handle_of(a1, ctx_a.mem);
            assert len(sv_live_edges(b1, 3, None, False, ctx_b.mem)) == 1;

            ctx_a.close();

            assert _g.osp_refs(h_a1, 3, -1, 0) == [] , "closed context's rows survived";
            outs = sv_live_edges(b1, 3, None, False, ctx_b.mem);
            assert len(outs) == 1 , "survivor context lost topology";
            assert outs[0] is b2 , "survivor traversal lost anchor identity";

            (c1, c2) = _connect_pair(ctx_b.mem, "c");
            assert len(sv_live_edges(c1, 3, None, False, ctx_b.mem)) == 1;
            assert len(sv_live_edges(b1, 3, None, False, ctx_b.mem)) == 1;

            ctx_b.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
