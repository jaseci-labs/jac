"""Planner E2E: engine execution in id space, overlay read-your-writes,
winner verification, and the cost invariant (L3 fetches == |result|)."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.query_planner { resolve_query }

node PA {
    has val: int = 0;
}

node PB {
    has tag: str = "";
}

edge PRel {
    has w: int = 0;
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "qp_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


"""root -PRel-> PA(1), PA(2), PA(3); PA(2) -PRel-> PB('leaf')."""
def _seed(ctx: ExecutionContext) -> UUID {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    pas: list = [];
    for i in [1, 2, 3] {
        nanch = PA(val=i).__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=PRel(w=i), source=ranch, target=nanch, is_undirected=False
        );
        eanch.persistent = True;
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        ctx.mem.put(nanch);
        ctx.mem.put(eanch);
        pas.append(nanch);
    }
    banch = PB(tag="leaf").__jac__;
    banch.persistent = True;
    e2 = EdgeAnchor(
        archetype=PRel(w=9), source=pas[1], target=banch, is_undirected=False
    );
    e2.persistent = True;
    pas[1].edges.append(e2);
    banch.edges.append(e2);
    ctx.mem.put(banch);
    ctx.mem.put(e2);
    return ranch.id;
}


test "cold engine query: preds, slice, and fetches == |result|" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ranch = ctx2.mem.get(root_id);
            assert isinstance(ranch, NodeAnchor) and ranch.archetype is not None;
            ctx2.mem.reset_fetch_count();

            q = GraphQuery(
                ranch.archetype,
                hops=[QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])]
            );
            hits = resolve_query(ctx2.mem, q);
            assert len(hits) == 1;
            assert hits[0].archetype.val == 2;
            fetches = ctx2.mem.get_fetch_count();
            assert fetches == 1 , (
                f"cost invariant: expected 1 L3 fetch (the winner), got {fetches}"
            );

            two = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype, hops=[QHop(dir=2, nd=PA)], slc=slice(0, 2, None)
                )
            );
            assert len(two) == 2;
            assert [a.archetype.val for a in two] == [1, 2];

            chain = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA),
                        QHop(
                            dir=2,
                            nd=PB,
                            preds=[QPred(field="tag", op="==", value="leaf")]
                        )
                    ]
                )
            );
            assert len(chain) == 1;
            assert chain[0].archetype.tag == "leaf";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "overlay: uncommitted writes are visible, both directions" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ranch = ctx2.mem.get(root_id);
            assert isinstance(ranch, NodeAnchor);

            # Fresh, uncommitted node+edge must appear (engine knows nothing).
            fresh = PA(val=99).__jac__;
            fresh.persistent = True;
            fe = EdgeAnchor(
                archetype=PRel(w=0), source=ranch, target=fresh, is_undirected=False
            );
            fe.persistent = True;
            ranch.edges.append(fe);
            fresh.edges.append(fe);
            ctx2.mem.put(fresh);
            ctx2.mem.put(fe);

            got = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(
                            dir=2, nd=PA, preds=[QPred(field="val", op="==", value=99)]
                        )
                    ]
                )
            );
            assert len(got) == 1 , "uncommitted edge must be visible (RYW)";

            # Dirty field write on a resident node: new value matches, old
            # value must not (the engine's committed row says val == 1).
            one = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=1)])
                    ]
                )
            );
            assert len(one) == 1;
            one[0].archetype.val = 42;

            after = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(
                            dir=2, nd=PA, preds=[QPred(field="val", op="==", value=42)]
                        )
                    ]
                )
            );
            assert len(after) == 1 , "dirty field write must be visible (RYW)";
            stale = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=1)])
                    ]
                )
            );
            assert len(stale) == 0 , "the committed value must no longer match";

            # Detaching a persisted edge suppresses its engine row.
            two_anchor = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])
                    ]
                )
            )[0];
            victim: (EdgeAnchor | None) = None;
            for stub in ranch.edges {
                loaded = ctx2.mem.get(stub.id);
                if isinstance(loaded, EdgeAnchor)
                    and loaded.is_populated()
                    and loaded.target.id == two_anchor.id {
                    victim = loaded;
                }
            }
            assert victim is not None;
            victim.detach();
            gone = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])
                    ]
                )
            );
            assert len(gone) == 0 , "detached edge must suppress its engine row";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
