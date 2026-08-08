"""NodeAnchor.edges read-path contract (#7963 item 1).

`NodeAnchor.edges` is a serialization artifact: it is written when persisting
and read at hydration to mint rows into the one osp_graph store. Live topology
("what edges does this node have right now") is answered only through the sv
driver (`sv_live_edges` / `sv_candidate_edges_between` / `sv_edge_alive`).

The scan below enforces that statically, in the style of the backend-purity
contract (#6542): every `.edges` occurrence in runtime sources must appear in
SANCTIONED with an exact count and a rationale. Growth means a live reader
crept back outside the driver seam (fix the code to consume the driver);
shrink means an entry earned tightening (edit the table). Either way the
change is deliberate and reviewed here.

The round-trip test pins the dynamic half: a persisted graph reloaded in a
fresh context traverses identically to the never-persisted run, so the
hydration mint inside `sv_register_hydrated` is the only anchor-list read the
live path depends on.
"""

import re;
import jaclang;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }

glob SCAN_ROOTS: list[str] = ["jac0core", "runtimelib", "scale", "byllm"],
     SANCTIONED: dict[str, tuple] = {
         "jac0core/impl/archetype.impl.jac": (
             4,
             "the field's own primitives: __getstate__ stubs the list for "
             "pickling, edge_delta derives the OCC add/remove sets, and "
             "remove_edge is the mutation bookkeeping detach() rides on"
         ),
         "jac0core/impl/runtime.impl.jac": (
             7,
             "mutation bookkeeping and persistence: build_edge's dual-write "
             "appends (the store write sits beside them), disconnect's "
             "stub-populate priming before driver hydration, save's cascade "
             "over unsaved edges, destroy's detach iteration, and "
             "reset_graph's persistence-record rewrite (paired with "
             "sv_forget_by_id so the store retracts in step)"
         ),
         "jac0core/osp_graph_sv.jac": (
             1,
             "THE hydration mint: sv_register_hydrated loading the "
             "persistence record into the store is the one sanctioned live "
             "read"
         ),
         "runtimelib/impl/query_planner.impl.jac": (
             1,
             "_walk_memory's volatile arm enumerates live anchor objects "
             "directly; detach keeps node.edges and the sv store in step, "
             "and the persistent arm is pure SQL (epic #7945)"
         ),
         "runtimelib/impl/serializer.impl.jac": (
             3,
             "serialization proper: writing data.edges on save and "
             "rebuilding the stub list plus _initial_edge_ids on load"
         ),
         "runtimelib/impl/session.impl.jac": (
             1,
             "hydration: _materialize rebuilds the stub list from the "
             "store's src/dst adjacency (ordered by seq) since node rows "
             "no longer rewrite on edge changes (epic #7945)"
         ),

     };

test "NodeAnchor.edges has no unsanctioned readers" {
    base = Path(str(jaclang.__file__)).parent;
    rx = re.compile(r"[.]edges\b");
    found: dict[str, int] = {};
    for sub in SCAN_ROOTS {
        for pat in ["*.jac", "*.py"] {
            for p in sorted((base / sub).rglob(pat)) {
                rel = str(p.relative_to(base)).replace("\\", "/");
                if "/tests/" in f"/{rel}" or "/fixtures/" in f"/{rel}" {
                    continue;
                }
                n = 0;
                for line in p.read_text(encoding="utf-8").splitlines() {
                    n += len(rx.findall(line));
                }
                if n > 0 {
                    found[rel] = n;
                }
            }
        }
    }
    problems: list[str] = [];
    for (rel, n) in sorted(found.items()) {
        want = SANCTIONED.get(rel);
        if want is None {
            problems.append(
                f"UNSANCTIONED: {rel} has {n} `.edges` reads. Live topology "
                "must go through the osp_graph_sv driver; if this is a "
                "persistence/hydration read, sanction it here with a "
                "rationale."
            );
        } elif n != want[0] {
            problems.append(
                f"COUNT DRIFT: {rel} has {n} `.edges` reads, sanctioned "
                f"{want[0]}. Review the change: new live readers belong in "
                "the driver; a removed read means this table should shrink."
            );
        }
    }
    for rel in sorted(SANCTIONED.keys()) {
        if rel not in found {
            problems.append(
                f"STALE ENTRY: {rel} is sanctioned but has no `.edges` "
                "reads; delete its entry."
            );
        }
    }
    assert not problems , "\n".join(problems);
}

node RoundTripNode {
    has label: str = "";
}

edge RoundTripEdge {
    has w: int = 0;
}

def _transcript(origin: any) -> list {
    out: list = [];
    for n in [origin-->] {
        if isinstance(n, RoundTripNode) {
            out.append(n.label);
            for m in [n->:RoundTripEdge:->] {
                out.append(f"{n.label}>{m.label}");
            }
        }
    }
    return out;
}

test "persisted graph traverses identically after reload in a fresh context" {
    with TemporaryDirectory() as proj {
        target = str(Path(proj) / "roundtrip_app.jac");
        orig_ctx = JacRuntime.exec_ctx;
        try {
            ctx_a = ExecutionContext(base_path_dir=proj, full_target_path=target);
            JacRuntime.exec_ctx = ctx_a;
            a = RoundTripNode(label="a");
            b = RoundTripNode(label="b");
            c = RoundTripNode(label="c");
            root ++> a;
            root ++> b;
            a +>:RoundTripEdge(w=1):+> c;
            live = _transcript(root);
            assert live == ["a", "a>c", "b"] , f"unexpected live transcript: {live}";
            ctx_a.close();

            ctx_b = ExecutionContext(base_path_dir=proj, full_target_path=target);
            JacRuntime.exec_ctx = ctx_b;
            reloaded = _transcript(root);
            assert reloaded == live , (
                f"reload transcript {reloaded} != live transcript {live}"
            );
            ctx_b.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
