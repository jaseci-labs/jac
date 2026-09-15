"""Index promotion must actually reach the query, and reach it usably.

Two defects made `[scale.database] indexes` a no-op. The promoted column was
never referenced -- `_pred_cond` emitted the raw jsonb path, and Postgres does
not substitute a generated column for its own defining expression. And the
column was `text` under a partial `WHERE arch_type = '<Arch>'` predicate, which
sorts numbers lexically and cannot be matched against the subtype-aware
arch_type test `compile_query` actually emits.

The column is now `jsonb` over `props->'archetype'->'<field>'` -- the same type
and the same expression the compiler already compares against -- indexed
without a predicate so subtypes are covered. These tests pin all three: the
column's shape, the index's usability, and the compiler naming it.
"""

import json;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID, uuid4 }
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }
import from jaclang.server.session { runtime_for_base }
import from jaclang.data.sqlcompile { CompiledQuery, compile_query }
import from jaclang.data.store { AnchorRow, PgStore }

node PMsg {
    has body: str = "",
        at: int = 0,
        seq: int = 0;
}

edge PPosted {}

glob PROMOS: dict[str, list[str]] = {"PMsg": ["at", "seq"]};


def _store(tmpdir: str) -> PgStore {
    lease = runtime_for_base(tmpdir, str(Path(tmpdir) / "pd_app.jac"));
    rt = lease.runtime;
    store = PgStore(
        conninfo=rt.ensure(), ensure_cb=rt.ensure, promotions=PROMOS, auto_schema=True
    );
    store.rows("SELECT 1", {});
    store.ensure_schema(PROMOS);
    return store;
}


"""Compiles against a real store, since a typed hop resolves its subtypes there."""
def _compile(q: GraphQuery) -> CompiledQuery {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            return compile_query(q, 1, store, promotions=PROMOS);
        } finally {
            store.close();
        }
    }
}


test "a promoted field becomes a jsonb column over the compared expression" {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            rows = store.rows(
                "SELECT data_type, is_generated FROM information_schema.columns "
                "WHERE table_name = 'anchors' AND column_name = :c",
                {"c": "g_pmsg_at"}
            );
            assert rows , "promotion did not create a column for PMsg.at";
            assert str(rows[0][0]) == "jsonb" , (
                f"promoted column must be jsonb so it matches the comparison the "
                f"compiler emits; got {rows[0][0]}"
            );
            assert str(rows[0][1]) == "ALWAYS" , rows[0][1];
        } finally {
            store.close();
        }
    }
}


test "the promoted index carries no arch_type predicate" {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            rows = store.rows(
                "SELECT indexdef FROM pg_indexes "
                "WHERE tablename = 'anchors' AND indexname = :n",
                {"n": "idx_g_pmsg_at"}
            );
            assert rows , "promotion did not create an index for PMsg.at";
            ddl = str(rows[0][0]);
            assert " WHERE " not in ddl , (
                f"a partial index cannot be matched against the subtype-aware "
                f"arch_type test compile_query emits: {ddl}"
            );
        } finally {
            store.close();
        }
    }
}


test "compile_query names the promoted column instead of the jsonb path" {
    q = GraphQuery(
        [], hops=[QHop(dir=2, nd=PMsg, preds=[QPred(field="at", op="==", value=7)])]
    );
    cq = _compile(q);
    assert "g_pmsg_at" in cq.sql , (
        f"promoted column not referenced; the index stays unreachable: {cq.sql}"
    );
    assert "props->'archetype'->'at'" not in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "an unpromoted field still compiles, via the jsonb path" {
    q = GraphQuery(
        [], hops=[QHop(dir=2, nd=PMsg, preds=[QPred(field="body", op="==", value="x")])]
    );
    cq = _compile(q);
    assert "props->'archetype'->'body'" in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "a composite key of field names against scalars constructs" {
    p = QPred(field=("at", "seq"), op="<", value=(5, 10));
    assert p.field == ("at", "seq");
    assert p.value == (5, 10);
}


test "a composite key rejects an arity mismatch" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="<", value=(5, ));
    } except TypeError {
        raised = True;
    }
    assert raised , "arity mismatch must not construct";
}


test "a composite key rejects a non-scalar element" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="<", value=(5, [1, 2]));
    } except TypeError {
        raised = True;
    }
    assert raised , "a non-scalar key element must not construct";
}


test "a composite key rejects an operator it cannot order by" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="in", value=(5, 10));
    } except ValueError {
        raised = True;
    }
    assert raised , "'in' has no row-comparison meaning";
}


test "a composite key matches lexicographically in object space" {
    p = QPred(field=("at", "seq"), op="<", value=(5, 10));
    assert p.matches((5, 9));
    assert not p.matches((5, 10));
    assert not p.matches((6, 0));
    assert p.matches((4, 999));
}


test "a promoted composite key compiles to a row comparison" {
    q = GraphQuery(
        [],
        hops=[
            QHop(
                dir=2,
                nd=PMsg,
                preds=[QPred(field=("at", "seq"), op="<", value=(5, 10))]
            )
        ]
    );
    cq = _compile(q);
    assert "(n1.g_pmsg_at, n1.g_pmsg_seq) <" in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "an unpromoted composite key still compiles, via the jsonb path" {
    q = GraphQuery(
        [],
        hops=[
            QHop(
                dir=2,
                nd=PMsg,
                preds=[QPred(field=("at", "body"), op="<", value=(5, "x"))]
            )
        ]
    );
    cq = _compile(q);
    assert not cq.residual , (
        f"correctness must not depend on whether an index was declared: "
        f"{cq.residual}"
    );
    assert "n1.g_pmsg_at" in cq.sql , cq.sql;
    assert "props->'archetype'->'body'" in cq.sql , cq.sql;
}


node PHub {}

node PRare {}

node PRareSub(PRare) {}

node PFiller {}

edge PLink {}


def _node_row(arch: str, ancestry: list[str]) -> AnchorRow {
    return AnchorRow(id=uuid4(), kind="NodeAnchor", arch_type=arch, ancestry=ancestry);
}


def _edge_row(src: UUID, dst: UUID, undirected: bool = False) -> AnchorRow {
    return AnchorRow(
        id=uuid4(),
        kind="EdgeAnchor",
        arch_type="PLink",
        src=src,
        dst=dst,
        undirected=undirected,
        ancestry=["PLink"]
    );
}


"""hub -> PRare x3, PRareSub x2, PFiller x5; PRare x3 -> hub; hub <-> PRare x2
stored one each way; hub -> hub. Returns the hub id."""
def _seed_hub(store: PgStore) -> UUID {
    hub = _node_row("PHub", ["PHub"]);
    rows: list[AnchorRow] = [hub, _edge_row(hub.id, hub.id)];
    for (arch, anc, count) in [
        ("PRare", ["PRare"], 3),
        ("PRareSub", ["PRareSub", "PRare"], 2),
        ("PFiller", ["PFiller"], 5)
    ] {
        for _ in range(count) {
            nd = _node_row(arch, anc);
            rows.append(nd);
            rows.append(_edge_row(hub.id, nd.id));
        }
    }
    for _ in range(3) {
        nd = _node_row("PRare", ["PRare"]);
        rows.append(nd);
        rows.append(_edge_row(nd.id, hub.id));
    }
    u1 = _node_row("PRare", ["PRare"]);
    u2 = _node_row("PRare", ["PRare"]);
    rows.append(u1);
    rows.append(u2);
    rows.append(_edge_row(hub.id, u1.id, undirected=True));
    rows.append(_edge_row(u2.id, hub.id, undirected=True));
    store.upsert(rows);
    return hub.id;
}


"""Hangs `count` PFiller leaves off one fresh bulk node, the hub-heavy degree
distribution real graphs have, then refreshes the planner statistics the way
autovacuum would after a bulk load."""
def _seed_filler(store: PgStore, count: int) -> int {
    bulk = _node_row("PFiller", ["PFiller"]);
    rows: list[AnchorRow] = [bulk];
    for _ in range(count) {
        nd = _node_row("PFiller", ["PFiller"]);
        rows.append(nd);
        rows.append(_edge_row(bulk.id, nd.id));
    }
    store.upsert(rows);
    store.rows("ANALYZE anchors", {});
    store.rows("ANALYZE graph_types", {});
    return len(rows);
}


def _rows_examined(plan: any) -> int {
    doc: any = json.loads(plan) if isinstance(plan, str) else plan;
    total = 0.0;
    stack: list[dict] = [doc[0]["Plan"]];
    while stack {
        nd = stack.pop();
        seen = 0.0;
        for key in [
            "Actual Rows",
            "Rows Removed by Filter",
            "Rows Removed by Join Filter",
            "Rows Removed by Index Recheck"
        ] {
            seen += float(nd.get(key, 0));
        }
        total += seen * float(nd.get("Actual Loops", 1));
        for child in list(nd.get("Plans") or []) {
            stack.append(child);
        }
    }
    return int(total);
}


"""Runs one typed hop from `origin` through the compiler and the store and
returns (node ids in result order, rows Postgres examined to answer it)."""
def _hop(
    store: PgStore, origin: UUID, dir: int, nd: (type | None)
) -> tuple[list[str], int, str] {
    q = GraphQuery([], hops=[QHop(dir=dir, `edge=PLink, nd=nd)]);
    cq = compile_query(q, 1, store);
    cq.params["origin"] = [str(origin)];
    got = [str(r[0]) for r in store.rows(cq.sql, cq.params)];
    plan = store.rows("EXPLAIN (ANALYZE, FORMAT JSON) " + cq.sql, cq.params)[0][0];
    return (got, _rows_examined(plan), str(plan));
}


test "a typed hop examines the same rows however many unrelated anchors exist" {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            hub = _seed_hub(store);
            cases: list[tuple[int, (type | None), int]] = [
                (2, PRare, 7),
                (1, PRare, 5),
                (3, PRare, 10),
                (2, PRareSub, 2),
                (3, PHub, 1),
                (2, None, 13)
            ];
            _seed_filler(store, 500);
            small = {(d, t): _hop(store, hub, d, t) for (d, t, _) in cases};
            added = _seed_filler(store, 4500);
            for (d, t, want) in cases {
                (ids, examined, plan) = _hop(store, hub, d, t);
                (ids0, examined0, _) = small[(d, t)];
                assert len(ids) == want and len(set(ids)) == want , (
                    f"dir={d} nd={t}: expected {want} distinct nodes, got {ids}"
                );
                assert ids == ids0 , f"dir={d} nd={t}: result changed: {ids0} -> {ids}";
                assert examined - examined0 < added // 8 , (
                    f"dir={d} nd={t}: rows examined grew with the {added} unrelated "
                    f"anchors, {examined0} -> {examined}; the hop is reading the "
                    f"table: {plan}"
                );
            }
        } finally {
            store.close();
        }
    }
}


test "a typed hop matches a subtype another store registered after this one opened" {
    with TemporaryDirectory() as td {
        store = _store(td);
        other = _store(td);
        try {
            hub = _seed_hub(store);
            late = _node_row("PRareLate", ["PRareLate", "PRare"]);
            other.upsert([late, _edge_row(hub, late.id)]);
            q = GraphQuery([], hops=[QHop(dir=2, `edge=PLink, nd=PRare)]);
            cq = compile_query(q, 1, store);
            assert "graph_types" not in cq.sql , cq.sql;
            assert "PRareLate" in cq.params["h1n0t"] , cq.params;
            cq.params["origin"] = [str(hub)];
            ids = [str(r[0]) for r in store.rows(cq.sql, cq.params)];
            assert str(late.id) in ids , f"subtype registered elsewhere missed: {ids}";
            assert len(ids) == 8 , ids;
        } finally {
            other.close();
            store.close();
        }
    }
}
