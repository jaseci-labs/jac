"""Parity suite for the pg-native Session (epic #7945).

The #7937 family: uncommitted attaches, detaches, and destroys must all be
visible to same-request traversals, because reads execute on the Session's
open transaction after the write barrier. Every test here runs against a
real embedded Postgres; the suite is the cutover gate for the clean break.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.jac0core.graph_query { GraphQuery, QHop }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.query_planner { resolve_query }

node SItem {
    has tag: str = "";
}

edge SRel {
    has w: int = 0;
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "pgs_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


def _attach(ctx: ExecutionContext, ranch: NodeAnchor, tag: str) -> NodeAnchor {
    nanch = SItem(tag=tag).__jac__;
    nanch.persistent = True;
    eanch = EdgeAnchor(
        archetype=SRel(), source=ranch, target=nanch, is_undirected=False
    );
    eanch.persistent = True;
    ranch.edges.append(eanch);
    nanch.edges.append(eanch);
    ctx.mem.put(nanch);
    ctx.mem.put(eanch);
    return nanch;
}


def _root(ctx: ExecutionContext) -> NodeAnchor {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    return ranch;
}


def _out_items(ctx: ExecutionContext, ranch: NodeAnchor) -> list {
    q = GraphQuery(ranch.archetype, hops=[QHop(dir=2, nd=SItem)]);
    return resolve_query(ctx.mem, q);
}


test "rywr: committed edge, uncommitted detach invisible to traversal (#7937)" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            it = _attach(ctx, ranch, "x");
            ctx.mem.commit();
            assert len(_out_items(ctx, ranch)) == 1;

            # uncommitted detach: unlink from edge lists, delete the anchor
            for e in list(ranch.edges) {
                ranch.edges.remove(e);
                it.edges.remove(e);
                ctx.mem.delete(e.id);
            }
            assert len(_out_items(ctx, ranch)) == 0 , (
                "#7937: uncommitted detach must be invisible to traversal"
            );

            ctx.mem.commit();
            assert len(_out_items(ctx, ranch)) == 0;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "rywr: uncommitted node destroy invisible to traversal" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            it = _attach(ctx, ranch, "x");
            ctx.mem.commit();
            assert len(_out_items(ctx, ranch)) == 1;

            for e in list(ranch.edges) {
                ranch.edges.remove(e);
                ctx.mem.delete(e.id);
            }
            ctx.mem.delete(it.id);
            assert len(_out_items(ctx, ranch)) == 0 , (
                "uncommitted destroy must be invisible to traversal"
            );
            assert ctx.mem.get(it.id) is None , (
                "get-after-delete must not resurrect from the store"
            );

            ctx.mem.commit();
            assert len(_out_items(ctx, ranch)) == 0;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "rywr: uncommitted attach visible; abort rolls it back" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            ctx.mem.commit();
            _attach(ctx, ranch, "fresh");
            assert len(_out_items(ctx, ranch)) == 1;

            ctx.mem.abort();
            assert len(_out_items(ctx, ranch)) == 0;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "get-after-delete does not resurrect from the store" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            it = _attach(ctx, ranch, "x");
            ctx.mem.commit();

            ctx.mem.delete(it.id);
            assert ctx.mem.get(it.id) is None;
            assert ctx.mem.batch_get([it.id]) == {};
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "persistence across sessions: same base path reopens the graph" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        rid: UUID;
        try {
            ranch = _root(ctx);
            _attach(ctx, ranch, "kept");
            ctx.mem.commit();
            rid = ranch.id;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            r2 = ctx2.mem.get(rid);
            assert r2 is not None;
            assert len(_out_items(ctx2, r2)) == 1;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "field mutation lands in the dirty set without a full-session sweep" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            it = _attach(ctx, ranch, "x");
            ctx.mem.commit();
            assert it.id not in ctx.mem._dirty;

            arch = it.archetype;
            assert isinstance(arch, SItem);
            arch.tag = "mutated";
            assert it.id in ctx.mem._dirty , (
                "plain field writes must mark the anchor dirty so read "
                "barriers can flush O(dirty) instead of rehashing the session"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "read barrier hashes only dirty anchors, not the whole session" {
    import jaclang.runtimelib.session;
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        smod = jaclang.runtimelib.session;
        orig = smod._persist_hash;
        calls: list = [];
        def counting_hash(anchor: Anchor) -> int {
            calls.append(1);
            return orig(anchor);
        }
        try {
            ranch = _root(ctx);
            items = [_attach(ctx, ranch, f"i{n}") for n in range(5)];
            ctx.mem.commit();

            smod._persist_hash = counting_hash;
            ctx.mem.read_barrier();
            assert len(calls) == 0 , f"clean session: read barrier must hash nothing, hashed {len(
                calls
            )}";

            arch0 = items[0].archetype;
            assert isinstance(arch0, SItem);
            arch0.tag = "touched";
            ctx.mem.read_barrier();
            assert len(calls) == 1 , f"one dirty anchor: read barrier must hash exactly it, hashed {len(
                calls
            )}";
        } finally {
            smod._persist_hash = orig;
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "on_commit fires exactly once, after successful commit" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            _root(ctx);
            fired: list = [];
            ctx.mem.on_commit(lambda { fired.append(1); });
            assert fired == [];
            ctx.mem.commit();
            assert fired == [1];
            ctx.mem.commit();
            assert fired == [1] , "on_commit must not refire on later commits";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
