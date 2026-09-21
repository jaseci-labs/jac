"""Ordering and bounding belong in the query, not in object space.

Results came back in edge-insertion order and nothing else. Ordering by a node
field meant materialising the whole neighbourhood and sorting it in Python, so
`[:50]` over a channel cost O(total messages). `GraphQuery` now carries an
ordering and a bound that compile to ORDER BY and LIMIT.

Ordering is sound to push unconditionally: it changes the sequence, not the
set, so a later ACL filter preserves it. A bound is not -- dropping rows in SQL
that the ACL layer would have dropped anyway is fine, but dropping rows *before*
the ACL filter changes what `[:n]` means from "n you may see" to "up to n, some
of which then vanish". So a bound is pushed only when the request is not
ACL-gated, and is applied in object space otherwise.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.graph_query { GraphQuery, QHop, QOrder }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.session { Session }
import from typing { cast }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.data.query_planner { resolve_query }
import from jaclang.data.sqlcompile { CompiledQuery, compile_query }

node OBoard {
    has name: str = "";
}

node OItem {
    has rank: int = 0,
        tag: str = "";
}

edge OHas: OBoard --> OItem {}


def _as_any(v: any) -> any {
    return v;
}

glob OPROMOS: dict[str, list[str]] = {"OItem": ["rank"]};


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "ord_app.jac")
    );
}


"""Compiles against a real store, since a typed hop resolves its subtypes there."""
def _compile(q: GraphQuery) -> CompiledQuery {
    with TemporaryDirectory() as td {
        ctx = _ctx(td);
        try {
            store = ctx.mem.store;
            assert store is not None;
            return compile_query(q, 1, store, promotions=OPROMOS);
        } finally {
            ctx.close();
        }
    }
}


def _seed -> OBoard {
    b = OBoard(name="b");
    root ++> b;
    for r in [3, 1, 4, 1, 5, 9, 2, 6] {
        b +>:OHas():+> OItem(rank=r, tag=f"t{r}");
    }
    return b;
}


test "an ordering compiles to ORDER BY on the hop's node alias" {
    q = GraphQuery(
        [], hops=[QHop(dir=2, nd=OItem)], order=[QOrder(field="rank", desc=True)]
    );
    cq = _compile(q);
    assert "n1.g_oitem_rank DESC" in cq.sql , cq.sql;
    assert "e1.seq" not in cq.sql , (
        f"an explicit ordering must replace the edge-sequence default: {cq.sql}"
    );
    assert "f0.ord" in cq.sql , (
        f"origin ordering must stay outermost so multi-origin results group: "
        f"{cq.sql}"
    );
}


test "an unpromoted ordering still compiles, via the jsonb path" {
    q = GraphQuery([], hops=[QHop(dir=2, nd=OItem)], order=[QOrder(field="tag")]);
    cq = _compile(q);
    assert "n1.props->'archetype'->'tag' ASC" in cq.sql , cq.sql;
}


test "no ordering keeps the edge-sequence default" {
    q = GraphQuery([], hops=[QHop(dir=2, nd=OItem)]);
    cq = _compile(q);
    assert "e1.seq" in cq.sql , cq.sql;
}


test "a bound compiles to LIMIT and OFFSET" {
    q = GraphQuery(
        [],
        hops=[QHop(dir=2, nd=OItem)],
        order=[QOrder(field="rank")],
        limit=5,
        offset=2
    );
    cq = _compile(q);
    assert "LIMIT 5" in cq.sql , cq.sql;
    assert "OFFSET 2" in cq.sql , cq.sql;
}


test "ordering drives real results, ascending and descending" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            asc = resolve_query(
                cast(Session, ctx.mem),
                GraphQuery(
                    b, hops=[QHop(dir=2, nd=OItem)], order=[QOrder(field="rank")]
                )
            );
            ranks = [_as_any(a).archetype.rank for a in asc];
            assert ranks == sorted(ranks) , ranks;
            desc = resolve_query(
                cast(Session, ctx.mem),
                GraphQuery(
                    b,
                    hops=[QHop(dir=2, nd=OItem)],
                    order=[QOrder(field="rank", desc=True)]
                )
            );
            dranks = [_as_any(a).archetype.rank for a in desc];
            assert dranks == sorted(dranks, reverse=True) , dranks;
            assert len(ranks) == 8 and len(dranks) == 8;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a bound returns the first n in the requested order" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            top = resolve_query(
                cast(Session, ctx.mem),
                GraphQuery(
                    b,
                    hops=[QHop(dir=2, nd=OItem)],
                    order=[QOrder(field="rank", desc=True)],
                    limit=3
                )
            );
            assert [_as_any(a).archetype.rank for a in top] == [9, 6, 5] , (
                [_as_any(a).archetype.rank for a in top]
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
