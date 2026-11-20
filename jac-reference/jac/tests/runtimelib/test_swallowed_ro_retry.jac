"""A read-only retry swallowed by user code still ends the attempt.

A unit runs on a read-only snapshot until it is seen writing. Its first write
rolls the attempt back and raises `ReadOnlyRetry`, so the server re-runs the
unit at SERIALIZABLE. `ReadOnlyRetry` is an `Exception`, so a broad
`except Exception` in user code (a scheduled docs sync, for one) swallowed it:
the attempt carried on over the rolled-back transaction, its earlier writes
were gone, and whatever it wrote after the swallow was committed on its own.
The session now remembers the raised retry and raises it again at the unit's
exit, after discarding the rest of the attempt, so the server still re-runs it.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID, uuid4 }
import from jaclang.runtime.archetype { NodeAnchor }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.exceptions { ReadOnlyRetry }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.session { Session }

node SrNote {
    has n: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "sr_app.jac")
    );
}


def _sess(ctx: ExecutionContext) -> Session {
    mem = ctx.mem;
    assert isinstance(mem, Session);
    return mem;
}


def _loose(ctx: ExecutionContext, n: int) -> NodeAnchor {
    anchor: NodeAnchor = _as_any(SrNote(n=n)).__jac__;
    anchor.persistent = True;
    ctx.mem.put(anchor);
    return anchor;
}


def _stored(ctx: ExecutionContext, id: UUID) -> (str | None) {
    probe = _as_any(ctx.mem.store).new_session();
    try {
        got = probe.rows(
            "SELECT props->'archetype'->>'n' FROM anchors WHERE id = CAST(:i AS uuid)",
            {"i": str(id)}
        );
    } finally {
        probe.close();
    }
    return str(got[0][0]) if got else None;
}


test "a swallowed read-only retry surfaces at the unit's exit" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            key = "tests.swallowed_ro_retry." + uuid4().hex;
            store = _as_any(sess.store);
            ctx.mem.commit();
            sess.unit_enter(key);
            _as_any(sess)._ensure_txn();
            assert str(store.txn_isolation()).endswith("SNAPSHOT_READ_ONLY") , (
                f"an unrecorded unit starts on a read-only snapshot, got {store.txn_isolation()}"
            );
            swallowed = False;
            try {
                sess.ensure_writable_txn();
            } except Exception {
                swallowed = True;
            }
            assert swallowed , "a read-only unit's first write must raise the retry";
            after = _loose(ctx, 7);
            refused = False;
            try {
                ctx.mem.commit();
            } except Exception {
                refused = True;
            }
            assert refused , (
                "a commit after the swallowed retry must not write: nested walks "
                "commit inside the unit, before its exit could discard anything"
            );
            surfaced = "";
            try {
                sess.unit_exit();
            } except ReadOnlyRetry as rr {
                surfaced = rr.unit_key;
            }
            assert surfaced == key , (
                "the unit's owner must still hear the retry the user code swallowed"
            );
            assert sess.unit_depth() == 0;
            assert _stored(ctx, after.ensure_id()) is None , (
                "a write made after the swallowed retry was committed on its own"
            );

            sess.unit_enter(key);
            kept = _loose(ctx, 8);
            ctx.mem.commit();
            sess.unit_exit();
            assert _stored(ctx, kept.ensure_id()) == "8" , (
                "the re-run, now known to write, commits normally"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
