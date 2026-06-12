"""Tier 1 tests for the graph ChangeSet (#6619).

The persistence layer must treat one request's writes as a unit of work:

- Mutations (including deletes) are recorded as typed intents, never
  flushed mid-request. A process that dies before commit leaves the
  persisted graph exactly as it was — no dangling references.
- `staged()` orders intents so that, even on a non-transactional backend,
  truncating the flush at any point can only leave unreferenced documents
  (orphans), never a reference to a missing document.
- `abort()` discards the uncommitted unit of work wholesale.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, NodeAnchor, Root }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.memory { SqliteMemory, TieredMemory }


node CsItem {
    has name: str = "";
}


"""A persistent ExecutionContext rooted in tmpdir (real L3 SQLite file)."""
def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "cs_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


"""Build root ++> CsItem in memory and stage it in the given TieredMemory."""
def _seed_graph(mem: TieredMemory) -> tuple {
    ranch = Root().__jac__;
    ranch.persistent = True;
    item = CsItem(name="victim");
    ianch = item.__jac__;
    ianch.persistent = True;
    eanch = EdgeAnchor(
        archetype=GenericEdge(), source=ranch, target=ianch, is_undirected=False
    );
    eanch.persistent = True;
    ranch.edges.append(eanch);
    ianch.edges.append(eanch);
    mem.put(ranch);
    mem.put(ianch);
    mem.put(eanch);
    return (ranch, ianch, eanch);
}


"""Open the DB as a fresh process would and list referential-integrity
violations: node rows citing missing edge rows, edge rows citing missing
endpoint rows. An empty list means the persisted graph is traversal-safe."""
def _integrity_violations(db_path: str) -> list[str] {
    import sqlite3;
    import from uuid { UUID }
    problems: list[str] = [];
    if not os.path.exists(db_path) {
        return problems;
    }
    raw = sqlite3.connect(db_path);
    row_ids = [r[0] for r in raw.execute("SELECT id FROM anchors").fetchall()];
    raw.close();
    fresh = SqliteMemory(path=db_path);
    all_anchors = [fresh.get(UUID(rid)) for rid in row_ids];
    for anchor in all_anchors {
        if isinstance(anchor, NodeAnchor) {
            for stub in anchor.edges {
                if not fresh.`has(stub.id) {
                    problems.append(f"node {anchor.id} cites missing edge {stub.id}");
                    continue;
                }
                loaded = fresh.get(stub.id);
                if isinstance(loaded, EdgeAnchor) {
                    for endp in (loaded.source, loaded.target) {
                        if endp is not None and not fresh.`has(endp.id) {
                            problems.append(
                                f"edge {loaded.id} cites missing node {endp.id}"
                            );
                        }
                    }
                }
            }
        }
    }
    return problems;
}


test "changeset stages creates in referential order" {
    import from jaclang.runtimelib.changeset { ChangeSet, WriteOp }
    ranch = Root().__jac__;
    item = CsItem().__jac__;
    eanch = EdgeAnchor(
        archetype=GenericEdge(), source=ranch, target=item, is_undirected=False
    );
    ranch.edges.append(eanch);
    item.edges.append(eanch);

    cs = ChangeSet();
    # Adversarial insertion order: the edge is recorded before its target.
    cs.record_create(eanch);
    cs.record_create(item);
    cs.record_create(ranch);

    flat_ops = [i.op.value for stage in cs.staged() for i in stage];
    assert flat_ops == sorted(flat_ops) , (
        f"stage order must be nondecreasing, got {flat_ops}"
    );
    node_stage = [
        i for stage in cs.staged()
        for i in stage
        if i.op == WriteOp.NODE_CREATE
    ];
    edge_stage = [
        i for stage in cs.staged()
        for i in stage
        if i.op == WriteOp.EDGE_CREATE
    ];
    assert len(node_stage) == 2 and len(edge_stage) == 1 , (
        "both nodes must stage as NODE_CREATE, the edge as EDGE_CREATE"
    );
}


test "changeset wires delete dependencies inverse of creates" {
    import from jaclang.runtimelib.changeset { ChangeSet, WriteOp }
    ranch = Root().__jac__;
    item = CsItem().__jac__;
    eanch = EdgeAnchor(
        archetype=GenericEdge(), source=ranch, target=item, is_undirected=False
    );
    ranch.edges.append(eanch);
    item.edges.append(eanch);

    cs = ChangeSet();
    # Mirror the destroy cascade: incident edges first, then the node.
    cs.record_delete(eanch);
    cs.record_delete(item);

    edge_intent = cs.intents[eanch.id];
    node_intent = cs.intents[item.id];
    assert edge_intent.op == WriteOp.EDGE_DELETE;
    assert node_intent.op == WriteOp.NODE_DELETE;
    # The node doc may go only after its incident edge docs are gone.
    assert eanch.id in node_intent.depends_on , (
        "NODE_DELETE must depend on its incident EDGE_DELETEs"
    );
    # The edge doc may go only after its endpoints' edge lists stop citing it.
    assert ranch.id in edge_intent.depends_on , (
        "EDGE_DELETE must depend on the source's edge-list repair"
    );
    # The surviving endpoint (root) gets an EDGE_LIST_DELTA removal intent.
    root_intent = cs.intents.get(ranch.id);
    assert root_intent is not None and root_intent.op == WriteOp.EDGE_LIST_DELTA , (
        "deleting an edge must record an edge-list removal on surviving endpoints"
    );
    assert eanch.id in root_intent.edges_removed;
    # Stage order: repairs, then edge docs, then node docs.
    flat_ops = [i.op.value for stage in cs.staged() for i in stage];
    assert flat_ops == sorted(flat_ops) , (
        f"stage order must be nondecreasing, got {flat_ops}"
    );
}


test "delete intent wins over earlier aspects for the same anchor" {
    import from jaclang.runtimelib.changeset { ChangeSet, WriteOp }
    item = CsItem().__jac__;
    cs = ChangeSet();
    cs.record_update(item, {'name'});
    cs.record_delete(item);
    assert cs.intents[item.id].op == WriteOp.NODE_DELETE , (
        "a delete recorded after a field update must supersede it"
    );
    # And a late edge-list delta on a deleted anchor must not resurrect it.
    cs.record_edge_delta(item, added=[], removed=[]);
    assert cs.intents[item.id].op == WriteOp.NODE_DELETE;
}


test "uncommitted delete cannot corrupt the persisted graph (crash window)" {
    with TemporaryDirectory() as tmpdir {
        ctx = _make_ctx(tmpdir);
        old_ctx = JacRuntime.exec_ctx;
        JacRuntime.exec_ctx = ctx;
        try {
            mem = ctx.mem;
            assert isinstance(mem, TieredMemory);
            (ranch, ianch, eanch) = _seed_graph(mem);
            mem.commit();
            db_path = mem.l3.path;
            assert _integrity_violations(db_path) == [] , "seed commit must be clean";

            # Destroy-style delete inside the request: detach in memory,
            # then delete both anchors. The process "dies" before commit —
            # we never call commit() or close() on this context.
            ranch.edges = [
                e
                for e in ranch.edges
                if e.id != eanch.id
            ];
            ianch.edges = [];
            mem.delete(eanch.id);
            mem.delete(ianch.id);

            problems = _integrity_violations(db_path);
            assert problems == [] , (
                "a crash between an in-request delete and commit corrupted "
                f"the persisted graph: {problems}"
            );
        } finally {
            JacRuntime.exec_ctx = old_ctx;
        }
    }
}


test "committed delete removes rows and repairs the edge list atomically" {
    with TemporaryDirectory() as tmpdir {
        ctx = _make_ctx(tmpdir);
        old_ctx = JacRuntime.exec_ctx;
        JacRuntime.exec_ctx = ctx;
        try {
            mem = ctx.mem;
            assert isinstance(mem, TieredMemory);
            (ranch, ianch, eanch) = _seed_graph(mem);
            mem.commit();
            db_path = mem.l3.path;

            ranch.edges = [
                e
                for e in ranch.edges
                if e.id != eanch.id
            ];
            ianch.edges = [];
            mem.delete(eanch.id);
            mem.delete(ianch.id);
            mem.commit();

            fresh = SqliteMemory(path=db_path);
            assert not fresh.`has(eanch.id) , "edge row must be gone after commit";
            assert not fresh.`has(ianch.id) , "node row must be gone after commit";
            reloaded = fresh.get(ranch.id);
            assert reloaded is not None , "root row must survive";
            assert reloaded.edges == [] , (
                f"root edge list must be repaired, got {reloaded.edges}"
            );
            assert _integrity_violations(db_path) == [];
        } finally {
            JacRuntime.exec_ctx = old_ctx;
        }
    }
}


test "abort discards the uncommitted unit of work" {
    with TemporaryDirectory() as tmpdir {
        ctx = _make_ctx(tmpdir);
        old_ctx = JacRuntime.exec_ctx;
        JacRuntime.exec_ctx = ctx;
        try {
            mem = ctx.mem;
            assert isinstance(mem, TieredMemory);
            (ranch, ianch, eanch) = _seed_graph(mem);
            mem.commit();
            db_path = mem.l3.path;

            # A failing request's work: one new node connected to root and
            # one delete of the existing item — then the walker raises.
            ghost = CsItem(name="ghost").__jac__;
            ghost.persistent = True;
            geanch = EdgeAnchor(
                archetype=GenericEdge(), source=ranch, target=ghost, is_undirected=False
            );
            geanch.persistent = True;
            ranch.edges.append(geanch);
            ghost.edges.append(geanch);
            mem.put(ghost);
            mem.put(geanch);
            ianch.edges = [];
            mem.delete(eanch.id);
            mem.delete(ianch.id);

            mem.abort();
            mem.commit();

            fresh = SqliteMemory(path=db_path);
            assert fresh.`has(ianch.id) , (
                "aborted delete must not remove the item row"
            );
            assert fresh.`has(eanch.id) , (
                "aborted delete must not remove the edge row"
            );
            assert not fresh.`has(ghost.id) , (
                "aborted create must not persist the ghost node"
            );
            reloaded = fresh.get(ranch.id);
            assert reloaded is not None;
            edge_ids = {e.id for e in reloaded.edges};
            assert edge_ids == {eanch.id} , (
                f"root edge list must be untouched after abort, got {edge_ids}"
            );
            assert _integrity_violations(db_path) == [];
        } finally {
            JacRuntime.exec_ctx = old_ctx;
        }
    }
}
