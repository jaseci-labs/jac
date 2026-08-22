"""The correctness invariant, as a permanent differential harness: every
spelling denoting the same query returns identical results, cold (engine)
and warm (resident), and fully-pushable queries deserialize exactly
|result| anchors. This is the test that makes the #7790 bug class
unrepresentable rather than merely fixed."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }

node DA {
    has val: int = 0;
}

node DB {
    has tag: str = "";
}

edge DE {
    has w: int = 0;
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "diff_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


"""root -DE(w)-> DA(1..3), DB('x'); DA(2) -DE(9)-> DB('leaf')."""
def _seed(ctx: ExecutionContext) -> UUID {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    das: list = [];
    payloads = [(DA(val=1), 1), (DA(val=2), 5), (DA(val=3), 7), (DB(tag="x"), 9)];
    for (arch, w) in payloads {
        nanch = arch.__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=DE(w=w), source=ranch, target=nanch, is_undirected=False
        );
        eanch.persistent = True;
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        ctx.mem.put(nanch);
        ctx.mem.put(eanch);
        das.append(nanch);
    }
    leaf = DB(tag="leaf").__jac__;
    leaf.persistent = True;
    e2 = EdgeAnchor(archetype=DE(w=9), source=das[1], target=leaf, is_undirected=False);
    e2.persistent = True;
    das[1].edges.append(e2);
    leaf.edges.append(e2);
    ctx.mem.put(leaf);
    ctx.mem.put(e2);
    return ranch.id;
}


def _vals(nodes: list) -> list {
    return [n.val for n in nodes];
}


test "spelling matrix is equivalent, cold and warm" {
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
            origin = ranch.archetype;

            # Cold: the engine resolves every hop in id space.
            nested = [origin-->[?:DA, val==2]];
            chained = [origin-->][?:DA][?val==2];
            mixed = [origin-->[?:DA]][?val==2];
            assert _vals(nested) == [2] , f"nested = {nested}";
            assert _vals(chained) == [2] , f"chained = {chained}";
            assert _vals(mixed) == [2] , f"mixed = {mixed}";

            # Warm: same answers with everything resident.
            assert _vals([origin-->[?:DA, val==2]]) == [2];
            assert _vals([origin-->][?:DA][?val==2]) == [2];
            assert _vals([origin-->[?:DA]][?val==2]) == [2];

            # Type-only, untyped, slices, ordering, edge preds, chains.
            assert len([origin-->]) == 4;
            assert len([origin-->[?:DA]]) == 3;
            assert len([origin-->][0:2]) == 2;
            assert _vals([origin-->[?:DA, val<=2]]) == [1, 2];
            heavy = [origin->:DE:w>4:->];
            assert len(heavy) == 3;
            two_hop = [origin-->[?:DA]-->[?:DB, tag=="leaf"]];
            assert len(two_hop) == 1;
            assert two_hop[0].tag == "leaf";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "cost invariant through real syntax: fetches == |result|" {
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
            origin = ranch.archetype;
            ctx2.mem.reset_fetch_count();
            winners = [origin-->[?:DA, val==2]];
            assert len(winners) == 1;
            fetches = ctx2.mem.get_fetch_count();
            assert fetches == 1 , (
                f"a fully-pushable query must deserialize exactly its result "
                f"set; got {fetches} fetches for 1 winner"
            );

            # A more selective query never reads more than a less selective
            # one (the #7790 P3 anomaly, inverted into an invariant).
            ctx2.mem.reset_fetch_count();
            all_da = [origin-->[?:DA]];
            broad = ctx2.mem.get_fetch_count();
            assert len(all_da) == 3;
            ctx2.mem.reset_fetch_count();
            narrow_hits = [origin-->[?:DA, val==3]];
            narrow = ctx2.mem.get_fetch_count();
            assert narrow <= broad , (
                f"selective query read more than broad one: {narrow} > {broad}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
