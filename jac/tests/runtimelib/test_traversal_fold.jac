"""Object-space operations on a traversal fold back into the query.

`[a --> [?:T]]` returned a fully materialised list, so `len(...)`, `[0]`,
`[:50]` and a truthiness test each cost O(degree) no matter how little of the
answer was wanted. The result is now realised lazily: the shapes that have a
SQL equivalent push into the query, and anything else realises first and
behaves exactly as a list did.

The contract these pin is that laziness is invisible. The value is still a
list, still compares equal to one, still supports every list operation. What
changes is how much of the graph had to be read to answer the question --
measured here through the session's fetch counter, which counts anchors
materialised into Python.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

node FBoard {
    has name: str = "";
}

node FItem {
    has rank: int = 0;
}

edge FHas: FBoard --> FItem {}

node FNoise {}

edge FNote: FBoard --> FItem {
    has note: str = "";
}

node FSub {
    has rank: int = 0;
}

edge FSubOf: FItem --> FSub {}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "fold_app.jac")
    );
}


def _seed(n: int) -> FBoard {
    b = FBoard(name="b");
    root ++> b;
    for i in range(n) {
        b +>:FHas():+> FItem(rank=i);
    }
    return b;
}


test "the result is still a list and still equal to one" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(6);
            ctx.mem.commit();
            got = [b->:FHas:->[?:FItem]];
            assert isinstance(got, list) , type(got);
            assert len(got) == 6;
            ranks = sorted([_as_any(x).rank for x in got]);
            assert ranks == [0, 1, 2, 3, 4, 5] , ranks;
            assert got == list(got);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "len() answers without materialising the neighbourhood" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(40);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            boards = [root-->[?:FBoard]];
            b2 = boards[0];
            ctx2.mem.reset_fetch_count();
            n = len([b2->:FHas:->[?:FItem]]);
            fetched = ctx2.mem.get_fetch_count();
            assert n == 40 , n;
            assert fetched == 0 , (
                f"len() materialised {fetched} anchors; a count has a SQL "
                f"equivalent and must not read the neighbourhood"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a truthiness test stops at the first row" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(40);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            boards = [root-->[?:FBoard]];
            b2 = boards[0];
            ctx2.mem.reset_fetch_count();
            assert [b2->:FHas:->[?:FItem]];
            fetched = ctx2.mem.get_fetch_count();
            assert fetched <= 1 , (
                f"a truthiness test materialised {fetched} anchors; it needs "
                f"at most one row to answer"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a slice reads only the slice" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(40);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            boards = [root-->[?:FBoard]];
            b2 = boards[0];
            ctx2.mem.reset_fetch_count();
            head = [b2->:FHas:->[?:FItem]][:5];
            fetched = ctx2.mem.get_fetch_count();
            assert len(head) == 5 , len(head);
            assert fetched <= 5 , (
                f"a 5-row slice materialised {fetched} anchors out of 40"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "an unfoldable operation realises and behaves exactly as a list" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(6);
            ctx.mem.commit();
            got = [b->:FHas:->[?:FItem]];
            got.reverse();
            assert len(got) == 6;
            first = _as_any(got)[0];
            got.append(first);
            assert len(got) == 7;
            counts = sorted([_as_any(x).rank for x in got]);
            assert len(counts) == 7 and len(set(counts)) == 6 , counts;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "an edges-only count counts edges, not their endpoints" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = FBoard(name="b");
            root ++> b;
            one = FItem(rank=0);
            b +>:FHas():+> one;
            b +>:FHas():+> one;
            b +>:FHas():+> FItem(rank=1);
            ctx.mem.commit();
            second = [_as_any(x).rank for x in [b-->[?:FItem]][1:2]];
            assert second == [1] , (
                f"a node slice skips nodes, not the edges that reach them; got {second}"
            );
            assert len([edge b-->]) == 3 , (
                f"two edges to one node is two edges; got {len([edge b-->])}"
            );
            assert len([b-->[?:FItem]]) == 2 , (
                f"...but one distinct node; got {len([b-->[?:FItem]])}"
            );
            assert [edge b-->] , "an edges-only truthiness test must see them";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a reference is evaluated where it appears, not where it is read" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed(3);
            ctx.mem.commit();
            snapshot = [b->:FHas:->[?:FItem]];
            b +>:FHas():+> FItem(rank=99);
            assert len(snapshot) == 3 , (
                f"the reference must hold the graph as of the line it was "
                f"written on; got {len(snapshot)} after a later attach"
            );
            fresh = [b->:FHas:->[?:FItem]];
            assert len(fresh) == 4 , f"a later reference sees it; got {len(fresh)}";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


def _seed_nested(items: int, subs: int) -> FBoard {
    b = FBoard(name="nested");
    root ++> b;
    for i in range(items) {
        it = FItem(rank=i);
        b +>:FHas():+> it;
        for j in range(subs) {
            it +>:FSubOf():+> FSub(rank=i * 100 + j);
        }
    }
    return b;
}


def _anchor_scans(ctx: ExecutionContext) -> int {
    store = ctx.mem.store;
    assert store is not None , "these tests need the Postgres store";
    rows = store.rows(
        "SELECT coalesce(idx_scan, 0) + coalesce(seq_scan, 0) "
            + "FROM pg_stat_xact_user_tables WHERE relname = 'anchors'",
        {}
    );
    return int(rows[0][0]) if rows else 0;
}


test "hops from nodes one query returned run once for all of them" {
    # (gated, bounded): a bounded read batches its follow-up hops too.
    for (gated, bounded) in [(False, False), (False, True), (True, True)] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _ctx(td);
            JacRuntime.exec_ctx = ctx;
            uid = "";
            try {
                if gated {
                    uid = _gated_root(ctx);
                    ctx.set_user_root(uid);
                }
                _seed_nested(12, 3);
                ctx.mem.commit();
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
            ctx2 = _ctx(td);
            JacRuntime.exec_ctx = ctx2;
            try {
                if gated {
                    ctx2.set_user_root(uid);
                }
                board = [root-->[?:FBoard]][0];
                items = list([board->:FHas:->[?:FItem]][:12])
                    if bounded
                    else list([board->:FHas:->[?:FItem]]);
                assert len(items) == 12;
                first = sorted(
                    [_as_any(x).rank for x in [items[0]->:FSubOf:->[?:FSub]]]
                );
                before = _anchor_scans(ctx2);
                got: dict[int, list[int]] = {};
                for it in items {
                    got[_as_any(it).rank] = sorted(
                        [_as_any(x).rank for x in [it->:FSubOf:->[?:FSub]]]
                    );
                }
                scans = _anchor_scans(ctx2) - before;
                for (rank, ranks) in got.items() {
                    assert ranks == [rank * 100, rank * 100 + 1, rank * 100 + 2] , (
                        rank,
                        ranks
                    );
                }
                assert first == got[_as_any(items[0]).rank];
                assert scans < 4 , (
                    f"hops from 12 nodes one query returned scanned anchors {scans} times "
                    f"after the first; they run as one batched hop ({gated}, {bounded})"
                );
            } finally {
                JacRuntime.exec_ctx = old;
                ctx2.close();
            }
        }
    }
}


test "a write between batched hops reaches the next hop" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            _seed_nested(6, 2);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            board = [root-->[?:FBoard]][0];
            items = list([board->:FHas:->[?:FItem]]);
            [items[0]->:FSubOf:->[?:FSub]];
            target = items[4];
            target +>:FSubOf():+> FSub(rank=999);
            ranks = sorted([_as_any(x).rank for x in [target->:FSubOf:->[?:FSub]]]);
            assert 999 in ranks , f"a sub-node connected before the hop was missed: {ranks}";
            assert len(ranks) == 3 , ranks;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a bounded hop from sibling nodes keeps each node's own bound" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            _seed_nested(5, 4);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            board = [root-->[?:FBoard]][0];
            items = list([board->:FHas:->[?:FItem]]);
            for it in items {
                head = [it->:FSubOf:->[?:FSub]][:2];
                assert len(head) == 2 , (_as_any(it).rank, head);
                base = _as_any(it).rank * 100;
                assert all(base <= _as_any(x).rank < base + 4 for x in head) , head;
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "batching stays off where a hop's answer is not fixed, and ends with the transaction" {
    import from jaclang.data.query_planner { resolve_query_prefix }
    import from jaclang.data.store { TxnIsolation }
    import from jaclang.runtime.graph_query { GraphQuery, QHop }
    import from jaclang.server.session { Session }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            _seed_nested(4, 2);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            board = [root-->[?:FBoard]][0];
            items = list([board->:FHas:->[?:FItem]]);
            first = items[0];
            sess = ctx2.mem;
            assert isinstance(sess, Session);
            prefix = resolve_query_prefix(
                sess, GraphQuery([first], hops=[QHop(dir=2, `edge=FSubOf, nd=FSub)]), 0
            );
            assert prefix == [first.__jac__.id] , prefix;
            assert len(sess.hop_siblings(first.__jac__.id)) == 4;
            sess.abort();
            assert sess.hop_siblings(first.__jac__.id) == () , (
                "a sibling group outlived the transaction that read it"
            );
            store = sess.store;
            assert store is not None;
            store.begin(TxnIsolation.READ_COMMITTED);
            try {
                again = list([[root-->[?:FBoard]][0]->:FHas:->[?:FItem]]);
                assert not sess.batching() , "read committed hops must not batch";
                for it in again {
                    base = _as_any(it).rank * 100;
                    ranks = sorted([_as_any(x).rank for x in [it->:FSubOf:->[?:FSub]]]);
                    assert ranks == [base, base + 1] , ranks;
                }
            } finally {
                store.rollback();
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


def _edge_types(ctx: ExecutionContext, where: str) -> list[tuple[str, str]] {
    store = ctx.mem.store;
    assert store is not None , "these tests need the Postgres store";
    rows = store.rows(
        "SELECT src_type, dst_type FROM anchors WHERE kind = 'EdgeAnchor' AND " + where,
        {}
    );
    return [(str(r[0]), str(r[1])) for r in rows];
}


test "typed hops in every direction reach their nodes through recorded endpoint types" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = FBoard(name="dirs");
            root ++> b;
            b ++> FItem(rank=0);
            FItem(rank=10) ++> b;
            b <++> FItem(rank=20);
            FItem(rank=21) <++> b;
            for _ in range(5) {
                b ++> FNoise();
                FNoise() ++> b;
                b <++> FNoise();
                FNoise() <++> b;
            }
            ctx.mem.commit();
            untyped = [
                t
                for t in _edge_types(ctx, "TRUE")
                if "" in t
            ];
            assert untyped == [] , f"edges written without endpoint types: {untyped}";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            b2 = [root-->[?:FBoard]][0];
            out = sorted([_as_any(x).rank for x in [b2-->[?:FItem]]]);
            inc = sorted([_as_any(x).rank for x in [b2<--[?:FItem]]]);
            both = sorted([_as_any(x).rank for x in [b2<-->[?:FItem]]]);
            assert out == [0, 20, 21] , out;
            assert inc == [10, 20, 21] , inc;
            assert both == [0, 10, 20, 21] , both;
            assert len([b2<-->[?:FNoise]]) == 20;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "an edge write takes its endpoint type from the stored node, not a stale copy" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = FBoard(name="stale");
            root ++> b;
            b +>:FNote(note="a"):+> FItem(rank=1);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            b2 = [root-->[?:FBoard]][0];
            items = [b2->:FNote:->[?:FItem]];
            notes = [edge b2->:FNote:->];
            assert len(items) == 1 and len(notes) == 1;
            iid = str(_as_any(items[0]).__jac__.id);
            other = _ctx(td);
            try {
                ostore = other.mem.store;
                assert ostore is not None;
                ostore.rows(
                    "UPDATE anchors SET arch_type = 'renamed.FItem' "
                        + "WHERE id = CAST(:i AS uuid)",
                    {"i": iid}
                );
                ostore.retype_edges([UUID(iid)]);
            } finally {
                other.close();
            }
            _as_any(notes[0]).note = "b";
            ctx2.mem.commit();
            assert _edge_types(ctx2, "props::text LIKE '%FNote%'")[0][1]
                == "renamed.FItem" , _edge_types(ctx2, "props::text LIKE '%FNote%'");
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "an edge rewritten without loading its endpoints keeps their types" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = FBoard(name="noted");
            root ++> b;
            b +>:FNote(note="a"):+> FItem(rank=1);
            ctx.mem.commit();
            typed = _edge_types(ctx, "props::text LIKE '%FNote%'");
            assert len(typed) == 1 and "" not in typed[0] , typed;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            b2 = [root-->[?:FBoard]][0];
            for e in [edge b2->:FNote:->] {
                assert not _as_any(e).__jac__.target.is_populated() , (
                    "the edge's target must stay a stub for this test"
                );
                _as_any(e).note = "b";
            }
            ctx2.mem.commit();
            assert _edge_types(ctx2, "props::text LIKE '%FNote%'") == typed;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
        ctx3 = _ctx(td);
        JacRuntime.exec_ctx = ctx3;
        try {
            b3 = [root-->[?:FBoard]][0];
            notes = [_as_any(e).note for e in [edge b3->:FNote:->]];
            assert notes == ["b"] , notes;
            assert [_as_any(x).rank for x in [b3->:FNote:->[?:FItem]]] == [1];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx3.close();
        }
    }
}


test "a node whose stored type changed is still reached by typed hops" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = FBoard(name="moved");
            root ++> b;
            item = FItem(rank=7);
            b ++> item;
            ctx.mem.commit();
            store = ctx.mem.store;
            assert store is not None;
            iid = str(_as_any(item).__jac__.id);
            store.rows(
                "UPDATE anchors SET arch_type = 'moved.FItem' "
                    + "WHERE id = CAST(:i AS uuid)",
                {"i": iid}
            );
            store.rows(
                "UPDATE anchors SET dst_type = 'moved.FItem' "
                    + "WHERE dst = CAST(:i AS uuid)",
                {"i": iid}
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            b2 = [root-->[?:FBoard]][0];
            for x in [b2-->] {
                _as_any(x).rank = 8;
            }
            ctx2.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
        ctx3 = _ctx(td);
        JacRuntime.exec_ctx = ctx3;
        try {
            b3 = [root-->[?:FBoard]][0];
            ranks = [_as_any(x).rank for x in [b3-->[?:FItem]]];
            assert ranks == [8] , (
                f"a node rewritten under its current type was missed by a typed hop: {ranks}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx3.close();
        }
    }
}


def _gated_root(ctx: ExecutionContext) -> str {
    import from jaclang.runtime.archetype { Root }
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    ctx.mem.put(anch);
    ctx.mem.commit();
    return str(anch.id);
}


def _gated_probe(b: any, probe: str) -> int {
    if probe == "typed count" {
        return len([b->:FHas:->[?:FItem]]);
    }
    if probe == "typed page" {
        return len([b->:FHas:->[?:FItem]][:5]);
    }
    if probe == "untyped count" {
        return len([b-->]);
    }
    if probe == "untyped empty page" {
        return len([b-->][:0]);
    }
    if probe == "bounded count" {
        import from jaclang.data.query_planner { resolve_query_count }
        import from jaclang.runtime.graph_query { GraphQuery, QHop }
        mem: any = JacRuntime.get_context().mem;
        return resolve_query_count(
            mem, GraphQuery(b, hops=[QHop(dir=2)], limit=5, offset=3)
        );
    }
    return len([b-->][:5]);
}


test "a gated caller's counts and pages stay bounded, typed or untyped" {
    # (probe, expected result at size n, fetch ceiling): a count reads no rows,
    # a page reads at most its own rows, at both sizes.
    rows = [
        ("typed count", -1, 0),
        ("typed page", 5, 5),
        ("untyped count", -1, 0),
        ("untyped page", 5, 5),
        ("untyped empty page", 0, 0),
        ("bounded count", 5, 0)
    ];
    for n in [40, 400] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _ctx(td);
            JacRuntime.exec_ctx = ctx;
            uid = "";
            try {
                uid = _gated_root(ctx);
                ctx.set_user_root(uid);
                _seed(n);
                ctx.mem.commit();
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
            for (probe, want, ceiling) in rows {
                ctx2 = _ctx(td);
                JacRuntime.exec_ctx = ctx2;
                try {
                    ctx2.set_user_root(uid);
                    b2 = [root-->[?:FBoard]][0];
                    ctx2.mem.reset_fetch_count();
                    got = _gated_probe(b2, probe);
                    fetched = ctx2.mem.get_fetch_count();
                    expect = n if want < 0 else want;
                    assert got == expect , (n, probe, got);
                    assert fetched <= ceiling , (
                        f"gated {probe} at n={n} materialised {fetched} anchors; "
                        f"the bound is {ceiling}"
                    );
                } finally {
                    JacRuntime.exec_ctx = old;
                    ctx2.close();
                }
            }
        }
    }
}


test "a keyset cursor walks a neighbourhood once, in edge order" {
    import from jaclang.data.query_planner {
        resolve_query,
        resolve_query_exists,
        resolve_query_page
    }
    import from jaclang.runtime.graph_query { GraphQuery, QHop, QOrder }
    import from jaclang.server.session { Session }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        uid = "";
        bid = "";
        try {
            uid = _gated_root(ctx);
            ctx.set_user_root(uid);
            bid = str(_as_any(_seed(23)).__jac__.id);
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        # (gated, page size): the cursor visits every neighbour exactly once in
        # insertion order, and a page never reads more than its own rows.
        for (gated, size) in [(False, 5), (True, 5), (True, 23), (True, 50)] {
            ctx2 = _ctx(td);
            JacRuntime.exec_ctx = ctx2;
            try {
                if gated {
                    ctx2.set_user_root(uid);
                }
                b2 = _as_any(ctx2.mem.get(UUID(bid))).archetype;
                sess = ctx2.mem;
                assert isinstance(sess, Session);
                ranks: list[int] = [];
                after: any = None;
                pages = 0;
                while True {
                    sess.reset_fetch_count();
                    (page, after) = resolve_query_page(
                        sess,
                        GraphQuery(
                            b2, hops=[QHop(dir=2, nd=FItem)], limit=size, after=after
                        )
                    );
                    assert sess.get_fetch_count() <= 2 * size , (
                        gated,
                        size,
                        sess.get_fetch_count()
                    );
                    for (a, e, _) in page {
                        assert e is not None and _as_any(e).archetype is not None;
                        ranks.append(_as_any(a).archetype.rank);
                    }
                    pages += 1;
                    if after is None {
                        break;
                    }
                }
                assert ranks == list(range(23)) , (gated, size, ranks);
                assert pages == (23 + size - 1) // size , (gated, size, pages);
                (tail_page, end) = resolve_query_page(
                    sess, GraphQuery(b2, hops=[QHop(dir=2, nd=FItem)], limit=size)
                );
                last = tail_page[-1][2];
                past = GraphQuery(b2, hops=[QHop(dir=2, nd=FItem)], after=last);
                if size >= 23 {
                    assert not resolve_query_exists(sess, past) , (
                        "a query past its last row must stay past it"
                    );
                }
                # (query, why it is refused): a cursor only means something in
                # edge order from one node, and must name the edge it resumes after.
                for (bad, why) in [
                    (
                        GraphQuery(
                            b2,
                            hops=[QHop(dir=2, nd=FItem)],
                            order=[QOrder(field="rank")],
                            after=last
                        ),
                        "custom order"
                    ),
                    (
                        GraphQuery(
                            b2, hops=[QHop(dir=2, nd=FItem)], after=(last[0], None)
                        ),
                        "no edge"
                    )
                ] {
                    refused = False;
                    try {
                        resolve_query(sess, bad);
                    } except ValueError {
                        refused = True;
                    }
                    assert refused , why;
                }
            } finally {
                JacRuntime.exec_ctx = old;
                ctx2.close();
            }
        }
    }
}


test "a page or a count from an in-memory node follows the store's semantics" {
    import from jaclang.data.query_planner {
        resolve_query,
        resolve_query_edges,
        resolve_query_page,
        resolve_query_type_counts
    }
    import from jaclang.runtime.graph_query { GraphQuery, QHop }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            stored = FBoard(name="stored");
            root ++> stored;
            for i in range(6) {
                stored +>:FNote(note=f"n{i}"):+> FItem(rank=i);
            }
            ctx.mem.commit();
            b = FBoard(name="transient");
            for i in range(6) {
                b +>:FHas():+> FItem(rank=i);
            }
            twice = FItem(rank=99);
            b +>:FNote():+> twice;
            b +>:FNote():+> twice;
            mem: any = ctx.mem;
            (head, resume) = resolve_query_page(
                mem, GraphQuery(b, hops=[QHop(dir=2, nd=FItem)], limit=3)
            );
            (page, _) = resolve_query_page(
                mem, GraphQuery(b, hops=[QHop(dir=2, nd=FItem)], limit=2, after=resume)
            );
            assert [_as_any(a).archetype.rank for (a, _, _) in page] == [3, 4] , page;
            # A page resumes from a cursor; an offset could not survive a page
            # that stops early, so both graphs refuse it.
            for origin in [b, stored] {
                refused = False;
                try {
                    resolve_query_page(
                        mem,
                        GraphQuery(
                            origin, hops=[QHop(dir=2, nd=FItem)], limit=2, offset=3
                        )
                    );
                } except ValueError {
                    refused = True;
                }
                assert refused , origin;
            }

            def shape(found: list[any]) -> list[any] {
                return [
                    x.archetype?.rank
                        if x.archetype?.rank is not None
                        else x.archetype?.note for x in found
                ];
            }
            parallel = FBoard(name="parallel");
            for i in range(6) {
                parallel +>:FNote(note=f"n{i}"):+> FItem(rank=i);
            }
            # (bound shape): every read, node or edge, plain or visit, bounds a
            # stored graph exactly as it bounds the same graph in memory. An
            # explicit limit wins over slc for plain reads; a visit's slc slices
            # its final edge-then-node list after a limit counted edges.
            shapes = [
                {"limit": 2},
                {"limit": 2, "offset": 1},
                {"slc": slice(1, 3)},
                {"limit": 2, "slc": slice(2, 3)},
                {"slc": slice(0, 5, 2)},
                {"limit": 4, "offset": 1, "slc": slice(1, 4)}
            ];
            for raw in shapes {
                bound: dict[str, any] = raw;
                for (edges_only, visiting) in [
                    (False, False),
                    (True, False),
                    (True, True)
                ] {
                    got: list[list[any]] = [];
                    for origin in [stored, parallel] {
                        gq = GraphQuery(
                            origin,
                            hops=[QHop(dir=2, nd=FItem)],
                            edges_only=edges_only,
                            limit=bound.get("limit"),
                            offset=bound.get("offset", 0),
                            slc=bound.get("slc")
                        );
                        if visiting {
                            gq = gq.visit();
                        }
                        got.append(
                            shape(
                                resolve_query_edges(mem, gq)
                                    if edges_only
                                    else resolve_query(mem, gq)
                            )
                        );
                    }
                    assert got[0] == got[1] , (bound, edges_only, visiting, got);
                }
            }
            (per_edge, _) = resolve_query_type_counts(
                mem, GraphQuery(b, hops=[QHop(dir=2)]), 'edge'
            );
            assert sum(per_edge.values()) == 8 , per_edge;
            (counts, _) = resolve_query_type_counts(
                mem, GraphQuery(b, hops=[QHop(dir=2)])
            );
            assert sum(counts.values()) == 7 , (
                f"a node reached by two edges is one node; got {counts}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
