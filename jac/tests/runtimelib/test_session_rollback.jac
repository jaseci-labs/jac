"""A rolled-back transaction must leave nothing behind in the session (#9879).

`Session` used to advance its record of what the database holds (the hash and
version of every flushed row, and the set of rows the transaction changed) the
moment a flush sent the rows, not when the transaction committed, and no
rollback path took any of it back. The session then believed in writes that
Postgres had discarded:

  1. A serialization failure at COMMIT was retried inside `commit`, but the
     retry sent each row at the version the rolled-back upsert had produced,
     so it could only ever fail with a `WriteConflict` on a row nobody else
     had touched.
  2. `abort()` kept every edge whose rolled-back props it had flushed, so a
     re-run of the request read the edge's uncommitted state back out of the
     session and wrote on top of a version that never existed.
  3. The changed-row set survived `abort()`, and the next conflict recovery
     read "changed and no longer in memory" as "deleted", deleting a row that
     was merely evicted.

Every conflict here is deterministic: either a real second connection commits
first, or COMMIT is made to fail the way Postgres fails a serializable
transaction (the transaction is rolled back and the client gets SQLSTATE
40001). Nothing depends on timing.
"""

import asyncio;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.data.type_identity { storage_type }
import from jaclang.runtime.archetype { NodeAnchor }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.exceptions { WriteConflict }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.session { MAX_RETRIES, RO_UNITS_ENV, Session }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

node RTally {
    has n: int = 0;
}

node RTallyKind(RTally) {}

edge RLink: any --> any {
    has w: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "rb_app.jac")
    );
}


def _sess(ctx: ExecutionContext) -> Session {
    mem = ctx.mem;
    assert isinstance(mem, Session);
    return mem;
}


"""A persistent node that hangs off nothing, so a test can delete it alone."""
def _loose(ctx: ExecutionContext, n: int) -> NodeAnchor {
    anchor: NodeAnchor = _as_any(RTally(n=n)).__jac__;
    anchor.persistent = True;
    ctx.mem.put(anchor);
    return anchor;
}


"""One archetype field as the database holds it, read on a connection of its
own so it sees committed state only. None when the row does not exist."""
def _stored(ctx: ExecutionContext, id: UUID, field: str) -> (str | None) {
    probe = _as_any(ctx.mem.store).new_session();
    try {
        got = probe.rows(
            "SELECT props->'archetype'->>CAST(:f AS text) FROM anchors"
            " WHERE id = CAST(:i AS uuid)",
            {"f": field, "i": str(id)}
        );
    } finally {
        probe.close();
    }
    return str(got[0][0]) if got else None;
}


"""Make the next `times` COMMITs of this session's open transaction fail the
way Postgres fails a serializable transaction at commit: the transaction is
rolled back and the client is told SQLSTATE 40001. Returns the countdown."""
def _fail_commits(sess: Session, times: int = 1) -> list[int] {
    store = _as_any(sess.store);
    real_commit = store.commit;
    left = [times];
    def failing_commit {
        if left[0] > 0 and store.in_txn() {
            left[0] -= 1;
            store.rollback();
            raise PgWireError(
                {
                    "C": "40001",
                    "M": "could not serialize access due to read/write"
                    " dependencies among transactions"
                }
            );
        }
        real_commit();
    }
    store.commit = failing_commit;
    return left;
}


test "consequence 1: a serialization failure at COMMIT is retried and the write lands" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            t = RTally(n=1);
            root ++> t;
            ctx.mem.commit();
            tid: UUID = _as_any(t).__jac__.id;

            t.n = 2;
            ctx.mem.mark_dirty(_as_any(t).__jac__);
            left = _fail_commits(_sess(ctx));
            ctx.mem.commit();

            assert left[0] == 0 , "the injected COMMIT failure never fired";
            assert _stored(ctx, tid, "n") == "2" , (
                "the retry inside commit must land the write: the failed COMMIT "
                "rolled the upsert back, so the row is still at the version the "
                f"session read; the database holds n={_stored(ctx, tid, 'n')}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "consequence 1: after a real serialization failure the conflict names the row that moved" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        seed = _ctx(td);
        JacRuntime.exec_ctx = seed;
        xid: UUID;
        yid: UUID;
        try {
            # Root resolution stores the super-root the first time it runs;
            # store it here so the two sessions below read it instead of both
            # trying to create it.
            _ = seed.user_root;
            xid = _loose(seed, 1).ensure_id();
            yid = _loose(seed, 2).ensure_id();
            seed.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            seed.close();
        }
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            # This session reads both rows, writes x, and flushes it.
            x = ctx.mem.get(xid);
            y = ctx.mem.get(yid);
            assert x is not None and y is not None;
            _as_any(x).archetype.n = 10;
            ctx.mem.mark_dirty(x);
            ctx.mem.flush();

            # A second session commits a change to y.
            rival = _ctx(td);
            JacRuntime.exec_ctx = rival;
            try {
                theirs = rival.mem.get(yid);
                assert theirs is not None;
                _as_any(theirs).archetype.n = 99;
                rival.mem.mark_dirty(theirs);
                rival.mem.commit();
            } finally {
                rival.close();
            }

            # Writing y now fails serialization in Postgres; the retry runs in
            # a new transaction, where x is unchanged and y is one version on.
            JacRuntime.exec_ctx = ctx;
            _as_any(y).archetype.n = 20;
            ctx.mem.mark_dirty(y);
            conflict: (WriteConflict | None) = None;
            try {
                ctx.mem.commit();
            } except WriteConflict as wc {
                conflict = wc;
            }
            assert conflict is not None , "a write over the rival's commit must conflict";
            blamed = "x" if conflict.anchor_id == xid else str(conflict.anchor_id);
            assert conflict.anchor_id == yid , (
                "the rival moved y and nobody moved x, so y is the conflict; the "
                f"session blamed {blamed} "
                f"(expected v{conflict.expected_version}, found v{conflict.actual_version})"
            );
            assert conflict.actual_version == conflict.expected_version + 1;

            # The re-run reads both again and commits on top of the rival.
            ctx.mem.abort();
            x2 = ctx.mem.get(xid);
            y2 = ctx.mem.get(yid);
            assert x2 is not None and y2 is not None;
            assert _as_any(y2).archetype.n == 99;
            _as_any(x2).archetype.n = 10;
            ctx.mem.mark_dirty(x2);
            _as_any(y2).archetype.n = 20;
            ctx.mem.mark_dirty(y2);
            ctx.mem.commit();
            assert _stored(ctx, xid, "n") == "10";
            assert _stored(ctx, yid, "n") == "20";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "consequence 1: the retry replays updates, inserts and deletes together" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            kept = _loose(ctx, 1);
            doomed = _loose(ctx, 2);
            ctx.mem.commit();

            _as_any(kept).archetype.n = 10;
            ctx.mem.mark_dirty(kept);
            ctx.mem.delete(doomed.ensure_id());
            fresh = _loose(ctx, 3);
            left = _fail_commits(_sess(ctx));
            ctx.mem.commit();

            assert left[0] == 0 , "the injected COMMIT failure never fired";
            assert _stored(ctx, kept.ensure_id(), "n") == "10" , "the update was lost";
            assert _stored(ctx, doomed.ensure_id(), "n") is None , (
                "the delete was lost: a delete the rolled-back transaction "
                "carried must be replayed with it"
            );
            assert _stored(ctx, fresh.ensure_id(), "n") == "3" , "the insert was lost";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "consequence 1: a COMMIT that keeps failing gives up as a conflict and loses nothing" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            t = RTally(n=1);
            root ++> t;
            ctx.mem.commit();
            tid: UUID = _as_any(t).__jac__.id;

            t.n = 2;
            ctx.mem.mark_dirty(_as_any(t).__jac__);
            left = _fail_commits(_sess(ctx), MAX_RETRIES + 1);
            raised = False;
            try {
                ctx.mem.commit();
            } except WriteConflict {
                raised = True;
            }
            assert left[0] == 0 , (
                f"commit must try {MAX_RETRIES + 1} times (one attempt and "
                f"{MAX_RETRIES} retries) before giving up; {left[0]} of the "
                "injected failures were never reached"
            );
            assert raised , (
                "once the retries are spent the failure must reach the caller as "
                "a conflict the request loop re-runs"
            );
            assert not _as_any(ctx.mem.store).in_txn() , (
                "a commit that gave up must not leave its transaction open"
            );
            assert _stored(ctx, tid, "n") == "1";

            # The unit is lost until it is aborted: whoever swallowed that
            # conflict (the walk's own end-of-walk commit does) must not be
            # able to commit it on a second try.
            again = False;
            try {
                ctx.mem.commit();
            } except WriteConflict {
                again = True;
            }
            assert again , "a lost unit committed on the next call";
            assert _stored(ctx, tid, "n") == "1";

            # The re-run: abort, do the work again, commit.
            ctx.mem.abort();
            rerun = ctx.mem.get(tid);
            assert rerun is not None;
            _as_any(rerun).archetype.n = 2;
            ctx.mem.mark_dirty(rerun);
            ctx.mem.commit();
            assert _stored(ctx, tid, "n") == "2" , "the re-run did not commit";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "consequence 2: an aborted edge write does not survive in the session" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        seed = _ctx(td);
        JacRuntime.exec_ctx = seed;
        eid: UUID;
        try {
            t = RTally(n=1);
            root +>:RLink(w=1):+> t;
            seed.mem.commit();
            eid = _as_any(t).__jac__.edges[0].id;
        } finally {
            JacRuntime.exec_ctx = old;
            seed.close();
        }
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            link = ctx.mem.get(eid);
            assert link is not None;
            _as_any(link).archetype.w = 5;
            ctx.mem.mark_dirty(link);
            ctx.mem.flush();
            ctx.mem.abort();

            again = ctx.mem.get(eid);
            assert again is not None;
            assert _as_any(again).archetype.w == 1 , (
                "abort rolled the edge's write back, so the session must read the "
                f"edge from the database again; it kept w={_as_any(again).archetype.w}"
            );

            _as_any(again).archetype.w = 5;
            ctx.mem.mark_dirty(again);
            ctx.mem.commit();
            assert _stored(ctx, eid, "w") == "5" , (
                "the re-run writes the same value the aborted attempt flushed; it "
                "must reach the database, at the version the database holds"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "consequence 3: a conflict after an abort does not delete rows the aborted attempt touched" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        seed = _ctx(td);
        JacRuntime.exec_ctx = seed;
        tid: UUID;
        uid: UUID;
        try {
            tid = _loose(seed, 1).ensure_id();
            uid = _loose(seed, 7).ensure_id();
            seed.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            seed.close();
        }
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            # Attempt one writes the tally and is aborted.
            first = ctx.mem.get(tid);
            assert first is not None;
            _as_any(first).archetype.n = 2;
            ctx.mem.mark_dirty(first);
            ctx.mem.flush();
            ctx.mem.abort();

            # Attempt two never loads it, and its COMMIT hits a conflict.
            assert ctx.mem.get(uid) is not None;
            left = _fail_commits(_sess(ctx));
            ctx.mem.commit();

            assert left[0] == 0 , "the injected COMMIT failure never fired";
            assert _stored(ctx, tid, "n") == "1" , (
                "a row the aborted attempt changed is not in memory because abort "
                "evicted it, not because anyone deleted it; the database holds "
                f"n={_stored(ctx, tid, 'n')}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a transaction Postgres rolled back on a failed statement does not lose its flushed writes" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            t = RTally(n=1);
            root ++> t;
            ctx.mem.commit();
            tid: UUID = _as_any(t).__jac__.id;

            t.n = 2;
            ctx.mem.mark_dirty(_as_any(t).__jac__);
            ctx.mem.flush();
            failed = False;
            try {
                _as_any(ctx.mem.store).rows("SELECT 1 / 0", {});
            } except PgWireError {
                failed = True;
            }
            assert failed , "the probe statement must fail";
            assert not _as_any(ctx.mem.store).in_txn() , (
                "a failed statement ends the transaction it ran in"
            );

            ctx.mem.commit();
            assert _stored(ctx, tid, "n") == "2" , (
                "the flushed write died with the transaction; the session must "
                "send it again instead of believing it is already stored"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a transaction another writer joined is re-run, never replayed without that writer" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            fresh = _loose(ctx, 1);
            # What the outbox does to enqueue an effect atomically with the
            # request: take the session's store, join its transaction, and
            # write a row of its own.
            store = _as_any(sess.store);
            sess.ensure_writable_txn();
            store.kv_put("rb_joined", "enqueued");
            left = _fail_commits(sess);
            raised = False;
            try {
                ctx.mem.commit();
            } except WriteConflict {
                raised = True;
            }
            assert left[0] == 0 , "the injected COMMIT failure never fired";
            assert raised , (
                "the rolled-back transaction carried a write the session does not "
                "own and cannot send again; committing only the session's half "
                "would drop it, so the unit has to be re-run"
            );
            assert _stored(ctx, fresh.ensure_id(), "n") is None , (
                "the session's half was committed without the joined write"
            );
            assert store.kv_get("rb_joined") is None , (
                "the joined write was rolled back with the transaction"
            );

            # A caller that swallows the conflict and commits again (the
            # walk's own end-of-walk commit does) must not get the half either.
            again = False;
            try {
                ctx.mem.commit();
            } except WriteConflict {
                again = True;
            }
            assert again , "a lost unit committed on the next call";
            assert _stored(ctx, fresh.ensure_id(), "n") is None;

            # The re-run: abort, do both writes again, commit.
            ctx.mem.abort();
            redo = _loose(ctx, 1);
            sess.ensure_writable_txn();
            store.kv_put("rb_joined", "enqueued");
            ctx.mem.commit();
            assert _stored(ctx, redo.ensure_id(), "n") == "1";
            assert store.kv_get("rb_joined") == "enqueued";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a rolled-back first write of a type registers the type again" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            store = _as_any(ctx.mem.store);
            first: NodeAnchor = _as_any(RTallyKind(n=1)).__jac__;
            first.persistent = True;
            ctx.mem.put(first);
            ctx.mem.flush();
            ctx.mem.abort();

            again: NodeAnchor = _as_any(RTallyKind(n=1)).__jac__;
            again.persistent = True;
            ctx.mem.put(again);
            ctx.mem.commit();

            probe = store.new_session();
            try {
                kinds = probe.subtype_names(storage_type(RTally));
            } finally {
                probe.close();
            }
            assert storage_type(RTallyKind) in kinds , (
                "the type's ancestry rows were rolled back with the aborted "
                "attempt, so the committed write has to register them again; "
                f"subtypes of RTally are {kinds}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a loaded anchor is hashed once (#9410)" {
    import from jaclang.data.serializer { Serializer }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        seed = _ctx(td);
        JacRuntime.exec_ctx = seed;
        ids: list[UUID] = [];
        try {
            ids = [_loose(seed, n).ensure_id() for n in range(4)];
            seed.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            seed.close();
        }
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        dumps_calls: list[int] = [];
        import json;
        real_dumps = json.dumps;
        def counting_dumps(*args: any, **kwargs: any) -> str {
            if kwargs.get("sort_keys") {
                dumps_calls.append(1);
            }
            return real_dumps(*args, **kwargs);
        }
        try {
            # Root resolution loads and may persist roots of its own; take it
            # before the counted load.
            _ = ctx.user_root;
            ctx.mem.commit();
            json.dumps = counting_dumps;
            try {
                loaded = ctx.mem.batch_get(ids);
            } finally {
                json.dumps = real_dumps;
            }
            assert len(loaded) == len(ids);
            assert len(dumps_calls) == len(ids) , (
                f"loading {len(ids)} anchors hashed {len(dumps_calls)} times; each "
                "anchor's stored form is hashed once, when it is deserialized"
            );
            ctx.mem.commit();
            for id in ids {
                assert _stored(ctx, id, "n") is not None;
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


"""The vote fixture behind the server's own execution manager, so a walker
runs through the real conflict loop. Returns the manager, the fixture's
walkers by name, and the fixture module (for its switches and run counter)."""
def _vote_app(td: str) -> tuple[any, dict[str, any], any] {
    import sys;
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.server.server {
        ExecutionManager,
        ModuleIntrospector,
        UserManager
    }
    jac_file = str((Path(FIXTURES) / "occ_vote.jac").resolve());
    introspector = ModuleIntrospector(
        module_name="occ_vote", base_path=str(Path(jac_file).parent)
    );
    prepare_application(jac_file, JacRuntime.get_program(), str(Path(jac_file).parent));
    introspector.load();
    walkers = introspector.get_walkers();
    user_mgr = UserManager(base_path=td);
    exec_mgr = ExecutionManager(base_path=td, user_manager=user_mgr);
    user_mgr.create_user("voter", "pw");
    mod = sys.modules[walkers["Vote"].__module__];
    mod.runs.clear();
    mod.rival_commits.clear();
    mod.commit_faults.clear();
    mod.failed_commits.clear();
    return (exec_mgr, walkers, mod);
}


def _spawn(exec_mgr: any, walker_cls: any) -> dict[str, any] {
    return _as_any(asyncio.run(exec_mgr.spawn_walker(walker_cls, {}, "voter")));
}


"""Read tiers re-run a writing unit once on their own; these tests count
conflict re-runs, so the unit starts out at SERIALIZABLE."""
def _without_read_tier -> (str | None) {
    prior = os.environ.get(RO_UNITS_ENV);
    os.environ[RO_UNITS_ENV] = "0";
    return prior;
}


def _restore_read_tier(prior: (str | None)) {
    if prior is None {
        os.environ.pop(RO_UNITS_ENV, None);
    } else {
        os.environ[RO_UNITS_ENV] = prior;
    }
}


test "request loop: a conflict re-run starts from the database, not from the rolled-back attempt" {
    prior = _without_read_tier();
    try {
        with TemporaryDirectory() as td {
            (exec_mgr, walkers, mod) = _vote_app(td);
            seeded = _spawn(exec_mgr, walkers["Seed"]);
            assert "error" not in seeded , f"seeding failed: {seeded}";
            mod.rival_commits.append(1);
            voted = _spawn(exec_mgr, walkers["Vote"]);
            assert mod.rival_commits == [] , "the rival writer never ran";
            assert "error" not in voted , (
                "one concurrent writer moved the poll once; the re-run reads the "
                f"new state and must commit, but the request ended with {voted}"
            );
            assert len(mod.runs) == 2 , (
                f"one conflict costs one re-run; the walker ran {len(mod.runs)} times"
            );
            tally = _spawn(exec_mgr, walkers["Tally"]);
            assert tally.get("reports") == [{"cast": True, "total": 101}] , (
                "the re-run must cast the ballot the aborted attempt only flushed, on "
                f"top of the rival write: {tally}"
            );
        }
    } finally {
        _restore_read_tier(prior);
    }
}


test "request loop: a COMMIT conflict the session retries does not cost a re-run" {
    prior = _without_read_tier();
    try {
        with TemporaryDirectory() as td {
            (exec_mgr, walkers, mod) = _vote_app(td);
            seeded = _spawn(exec_mgr, walkers["Seed"]);
            assert "error" not in seeded , f"seeding failed: {seeded}";
            mod.commit_faults.append(1);
            voted = _spawn(exec_mgr, walkers["Vote"]);
            assert mod.commit_faults == [] , "the COMMIT failure was never armed";
            assert "error" not in voted , f"the vote failed: {voted}";
            assert len(mod.runs) == 1 , (
                "the session retried the COMMIT itself, so the request loop has "
                f"nothing to re-run; the walker ran {len(mod.runs)} times"
            );
            tally = _spawn(exec_mgr, walkers["Tally"]);
            assert tally.get("reports") == [{"cast": True, "total": 1}] , f"{tally}";
        }
    } finally {
        _restore_read_tier(prior);
    }
}


test "request loop: a COMMIT that never succeeds is re-run up to conflict_max_attempts, then 409" {
    import from jaclang.server.server { _occ_policy }
    prior = _without_read_tier();
    try {
        with TemporaryDirectory() as td {
            (exec_mgr, walkers, mod) = _vote_app(td);
            seeded = _spawn(exec_mgr, walkers["Seed"]);
            assert "error" not in seeded , f"seeding failed: {seeded}";
            (mode, max_attempts, _backoff) = _occ_policy();
            attempts = 1 if mode == "fail" else max(1, max_attempts);
            # Every run spends the session's whole retry budget on its COMMIT.
            mod.commit_faults.extend([MAX_RETRIES + 1] * attempts);
            voted = _spawn(exec_mgr, walkers["Vote"]);
            assert voted.get("error_code") == "write_conflict" , f"{voted}";
            assert voted.get("http_status") == 409 , f"{voted}";
            assert len(mod.runs) == attempts , (
                f"the request loop owns the re-runs: {attempts} attempts allowed, "
                f"the walker ran {len(mod.runs)} times"
            );
            assert len(mod.failed_commits) == attempts * (MAX_RETRIES + 1) , (
                f"each attempt retries its COMMIT {MAX_RETRIES} times before the "
                f"session hands the conflict to the request loop; "
                f"{len(mod.failed_commits)} COMMITs failed in {attempts} attempts"
            );
            tally = _spawn(exec_mgr, walkers["Tally"]);
            assert tally.get("reports") == [{"cast": False, "total": 0}] , (
                f"a request answered 409 must leave nothing behind: {tally}"
            );
        }
    } finally {
        _restore_read_tier(prior);
    }
}
