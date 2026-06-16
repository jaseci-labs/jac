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
import from jaclang.runtimelib.changeset { ChangeSet }
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


"""A stage whose iteration raises: simulates a transaction-level failure
(not a per-intent one) that strikes after the real stages have executed."""
obj _BoomStage {
    def __iter__ {
        raise RuntimeError("forced transaction-level failure");
    }
}


"""Changeset wrapper that appends a transaction-level failure after the
real stages, so apply()'s outer rollback path is exercised."""
obj _PoisonTailChangeSet {
    has inner: ChangeSet;

    def is_empty -> bool {
        return self.inner.is_empty();
    }

    def staged -> list {
        out: list = list(self.inner.staged());
        out.append(_BoomStage());
        return out;
    }
}


test "quarantine during apply must not split the transaction" {
    import sqlite3;
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

            # Corrupt the item's stored row so the next merge-aware write
            # hits the apply-time deserialize -> quarantine path.
            raw = sqlite3.connect(db_path);
            raw.execute(
                "UPDATE anchors SET data = ? WHERE id = ?",
                ("this is not json", str(ianch.id))
            );
            raw.commit();
            raw.close();

            # One unit of work: a new node create (stage 0) plus a field
            # update on the corrupt row (stage 3, triggers _quarantine).
            # The poison tail then fails the transaction AFTER both ran.
            # All-or-nothing: the rollback must undo the create AND the
            # quarantine — not just whatever followed the quarantine.
            ghost = CsItem(name="ghost").__jac__;
            ghost.persistent = True;
            cs = ChangeSet();
            cs.record_create(ghost);
            ianch.archetype.name = "renamed";
            cs.record_update(ianch, {"name"});

            try {
                mem.l3.apply(_PoisonTailChangeSet(inner=cs));
            } except Exception { }

            check = sqlite3.connect(db_path);
            q_count = check.execute(
                "SELECT COUNT(*) FROM anchors_quarantine"
            ).fetchone()[0];
            item_row = check.execute(
                "SELECT data FROM anchors WHERE id = ?", (str(ianch.id), )
            ).fetchone();
            ghost_row = check.execute(
                "SELECT id FROM anchors WHERE id = ?", (str(ghost.id), )
            ).fetchone();
            check.close();

            assert q_count == 0 , (
                "rolled-back transaction must not leave a quarantine row: "
                "_quarantine committed mid-flush and split the transaction"
            );
            assert item_row is not None and item_row[0] == "this is not json" , (
                "rolled-back transaction must leave the (corrupt) stored row "
                f"exactly as it was; got {item_row}"
            );
            assert ghost_row is None , (
                "rolled-back transaction must not persist the staged create: "
                "a mid-flush commit made the rollback partial"
            );
        } finally {
            JacRuntime.exec_ctx = old_ctx;
        }
    }
}


test "field change without a hash snapshot is not dropped when an edge delta rides along" {
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

            # Simulate an anchor loaded through a tier that never snapshot
            # per-field hashes (e.g. an L2 cache hit): derive_dirty_fields
            # is blind for this anchor.
            ianch.archetype.__dict__.pop('__jac_field_hashes__', None);

            # The request mutates a field AND the edge list. The edge delta
            # alone must not satisfy the collect pass: with no per-field
            # signal available, the field change has to ride a full merged
            # rewrite — not be silently dropped.
            ianch.archetype.name = "renamed";
            extra = CsItem(name="extra").__jac__;
            extra.persistent = True;
            xeanch = EdgeAnchor(
                archetype=GenericEdge(), source=ianch, target=extra, is_undirected=False
            );
            xeanch.persistent = True;
            ianch.edges.append(xeanch);
            extra.edges.append(xeanch);
            mem.put(extra);
            mem.put(xeanch);
            mem.commit();

            fresh = SqliteMemory(path=db_path);
            reloaded = fresh.get(ianch.id);
            assert reloaded is not None;
            assert reloaded.archetype.name == "renamed" , (
                "field mutation was dropped: an edge delta on the same anchor "
                "must not mask field changes when no field-hash snapshot exists"
            );
            assert fresh.`has(extra.id) , "new node must persist";
            assert _integrity_violations(db_path) == [];
        } finally {
            JacRuntime.exec_ctx = old_ctx;
        }
    }
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
