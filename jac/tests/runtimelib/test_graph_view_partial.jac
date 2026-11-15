"""The graph explorer must render what it can, not 500 on one bad edge, must
render only what the caller may read, and must cost one page, not the graph.

`graph_node_view` and `graph_neighbors_view` back /graph/node and
/graph/neighbors. A node whose edge list cites an anchor that cannot be loaded
in this process (quarantined row, peer service's class in a shared store,
legacy corruption) must be skipped -- raising turns one dangling reference into
a blank view. A node the caller cannot read must be left out too, along with
the edge to it: a page is a read, so it answers to the same permission test a
walker's traversal does. And a page reads one page of rows however large or
deep the graph behind it is.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }

import from jaclang.runtime.archetype { AccessLevel, EdgeAnchor, GenericEdge, Root }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.graph_utils { graph_neighbors_view, graph_node_view }
import from jaclang.runtime.runtime { JacRuntime }


node Doc {
    has label: str = "";
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "graph_app.jac")
    );
}


def _as_any(v: any) -> any {
    return v;
}


def _mk_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    mem.put(anch);
    return anch;
}


"""A persistent Doc owned by `owner`, open to everyone at `public` if given."""
def _doc(mem: any, owner: any, label: str, public: any = None) -> any {
    d: any = Doc(label=label).__jac__;
    d.persistent = True;
    setattr(d, "root", owner.id);
    if public is not None {
        d.own_access().all = public;
    }
    mem.put(d);
    return d;
}


def _link(mem: any, src: any, dst: any) {
    e: any = EdgeAnchor(
        archetype=GenericEdge(), source=src, target=dst, is_undirected=False
    );
    e.persistent = True;
    setattr(e, "root", src.root or src.id);
    src.edges.append(e);
    dst.edges.append(e);
    mem.put(e);
}


def _labels(page: dict[str, any], mem: any) -> list[str] {
    out: list[str] = [];
    for n in page["nodes"] {
        a: any = mem.get(UUID(n["id"]));
        out.append("root" if n["root"] else a.archetype.label);
    }
    return sorted(out);
}


test "the explorer leaves out what the caller cannot read" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        alice_id: str;
        bob_id: str;
        hub_id: str;
        try {
            alice = _mk_root(ctx1.mem);
            bob = _mk_root(ctx1.mem);
            hub = _doc(ctx1.mem, alice, "alice-hub");
            _link(ctx1.mem, alice, hub);
            _link(ctx1.mem, hub, _doc(ctx1.mem, alice, "alice-own"));
            _link(ctx1.mem, hub, _doc(ctx1.mem, bob, "bob-public", AccessLevel.READ));
            hidden = _doc(ctx1.mem, bob, "bob-private");
            _link(ctx1.mem, hub, hidden);
            _link(ctx1.mem, hidden, _doc(ctx1.mem, alice, "behind-bob-private"));
            _link(ctx1.mem, bob, hub);
            _link(ctx1.mem, bob, _doc(ctx1.mem, bob, "bob-note"));
            ctx1.mem.commit();
            alice_id = str(alice.id);
            bob_id = str(bob.id);
            hub_id = str(hub.id);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ctx2.set_user_root(alice_id);
            hub_arch: any = _as_any(ctx2.mem.get(UUID(hub_id))).archetype;
            root_arch: any = _as_any(ctx2.mem.get(UUID(alice_id))).archetype;
            # (origin, dir, labels alice may see): the unreadable doc, bob's root
            # and whatever lies behind them never surface.
            rows = [
                (root_arch, "out", ["alice-hub"]),
                (hub_arch, "out", ["alice-own", "bob-public"]),
                (hub_arch, "in", ["root"]),
                (hub_arch, "both", ["alice-own", "bob-public", "root"])
            ];
            for (origin, direction, want) in rows {
                page = graph_neighbors_view(origin, direction=direction);
                got = _labels(page, ctx2.mem);
                assert got == want , (direction, got);
                ends = {x for e in page["edges"] for x in (e["from"], e["to"])};
                assert UUID(bob_id).hex not in ends , (
                    "bob's root is not readable to alice, so no edge may surface its id"
                );
            }
            view = graph_node_view(hub_arch);
            assert view["type"] == "Doc"
                and view["fields"]["label"] == "'alice-hub'" , view;
            out_nodes = view["counts"]["out"]["nodes"];
            in_nodes = view["counts"]["in"]["nodes"];
            assert sum(out_nodes.values()) == 2 , out_nodes;
            assert sum(in_nodes.values()) == 1 , in_nodes;
            assert sum(view["counts"]["out"]["edges"].values()) == 2 , view["counts"];
            assert view["counts"]["in"]["exact"] and view["counts"]["out"]["exact"] , (
                "a handful of hook-decided neighbors is counted exactly"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a neighbors page costs one page at any size and any depth" {
    # (kind, size): a wide hub and a chain deeper than Python's recursion limit.
    for (kind, size) in [("wide", 60), ("wide", 600), ("deep", 13000)] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx1 = _ctx(td);
            JacRuntime.exec_ctx = ctx1;
            owner_id: str;
            head_id: str;
            try {
                owner = _mk_root(ctx1.mem);
                head = _doc(ctx1.mem, owner, "head");
                _link(ctx1.mem, owner, head);
                prev = head;
                for i in range(size) {
                    nxt = _doc(ctx1.mem, owner, f"n{i}");
                    _link(ctx1.mem, prev if kind == "deep" else head, nxt);
                    prev = nxt;
                }
                ctx1.mem.commit();
                owner_id = str(owner.id);
                head_id = str(head.id);
            } finally {
                JacRuntime.exec_ctx = old;
                ctx1.close();
            }
            ctx2 = _ctx(td);
            JacRuntime.exec_ctx = ctx2;
            try {
                ctx2.set_user_root(owner_id);
                head_arch: any = _as_any(ctx2.mem.get(UUID(head_id))).archetype;
                ctx2.mem.reset_fetch_count();
                page = graph_neighbors_view(head_arch, limit=10);
                fetched = ctx2.mem.get_fetch_count();
                want = 1 if kind == "deep" else 10;
                assert len(page["nodes"]) == want , (kind, size, len(page["nodes"]));
                assert (page["next_cursor"] is not None) == (kind == "wide") , page;
                assert fetched <= 2 * want , (
                    f"a {want}-row page over a {kind} graph of {size} read {fetched} anchors"
                );
                ctx2.mem.reset_fetch_count();
                view = graph_node_view(head_arch);
                assert ctx2.mem.get_fetch_count() == 0 , "counts must not load neighbors";
                assert sum(view["counts"]["out"]["nodes"].values())
                    == (1 if kind == "deep" else size) , view["counts"];
            } finally {
                JacRuntime.exec_ctx = old;
                ctx2.close();
            }
        }
    }
}


test "a neighbors page skips an edge whose target row is gone instead of raising" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        owner_id: str;
        try {
            owner = _mk_root(ctx1.mem);
            _link(ctx1.mem, owner, _doc(ctx1.mem, owner, "kept"));
            broken = _doc(ctx1.mem, owner, "broken");
            _link(ctx1.mem, owner, broken);
            ctx1.mem.commit();
            owner_id = str(owner.id);
            store: any = ctx1.mem.store;
            store.rows(
                "DELETE FROM anchors WHERE id = CAST(:i AS uuid)", {"i": str(broken.id)}
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ctx2.set_user_root(owner_id);
            root_arch: any = _as_any(ctx2.mem.get(UUID(owner_id))).archetype;
            page = graph_neighbors_view(root_arch);
            assert _labels(page, ctx2.mem) == ["kept"] , page;
            assert len(page["edges"]) == 1 , page;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "printgraph keeps node_limit in every format" {
    import json;
    import from jaclang.runtime.builtin { printgraph }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            for i in range(5) {
                root ++> Doc(label=f"d{i}");
            }
            # (format, how many nodes the output draws): a BFS must not queue
            # past the limit, whatever it prints.
            rows = [
                ("json", lambda (out: str) -> int { len(json.loads(out)["nodes"]); }),
                (
                    "dot",
                    lambda (out: str) -> int { len(
                        [
                            l
                            for l in out.splitlines()
                            if "[label=" in l and "->" not in l
                        ]
                    ); }
                ),
                (
                    "mermaid",
                    lambda (out: str) -> int { len(
                        [
                            l
                            for l in out.splitlines()
                            if '["' in l
                        ]
                    ); }
                )
            ];
            for (fmt, drawn) in rows {
                out = printgraph(nd=root, node_limit=2, format=fmt);
                assert drawn(out) == 2 , (fmt, out);
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
