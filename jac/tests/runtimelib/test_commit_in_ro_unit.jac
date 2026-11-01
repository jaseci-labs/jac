"""A read-only unit that commits a write is not re-run from the start.

A unit runs on a read-only snapshot until it is seen writing, and its first
write normally raises `ReadOnlyRetry` so the server re-runs it at SERIALIZABLE.
A write committed inside the unit (`commit()`, or a nested walk) is the
exception: it reaches the store at SERIALIZABLE without the retry. The next
transaction was read-only again, so a later write raised the retry and the
server re-ran the whole unit, repeating the write that was already committed.
The commit now records the unit as a writer, so the later write runs at
SERIALIZABLE and nothing is repeated. That holds whether the write is still
pending at the commit or a read barrier (any graph query) already flushed it.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID, uuid4 }
import from jaclang.runtime.archetype { NodeAnchor }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.session { Session, unit_writes_recorded }

node CmNote {
    has n: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "cm_app.jac")
    );
}


def _sess(ctx: ExecutionContext) -> Session {
    mem = ctx.mem;
    assert isinstance(mem, Session);
    return mem;
}


def _loose(ctx: ExecutionContext, n: int) -> NodeAnchor {
    anchor: NodeAnchor = _as_any(CmNote(n=n)).__jac__;
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


def _write_commit_write(flush_first: bool) {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            key = "tests.commit_in_ro_unit." + uuid4().hex;
            store = _as_any(sess.store);
            ctx.mem.commit();
            sess.unit_enter(key);
            first = _loose(ctx, 1);
            if flush_first {
                sess.read_barrier();
            }
            ctx.mem.commit();
            assert _stored(ctx, first.ensure_id()) == "1" , (
                "the write before the commit is saved by it"
            );
            assert unit_writes_recorded(key) , (
                "a unit that committed a write must be recorded as a writer"
            );
            _as_any(sess)._ensure_txn();
            assert str(store.txn_isolation()).endswith("SERIALIZABLE") , (
                f"the unit's next transaction must be writable, got {store.txn_isolation()}"
            );
            later = _loose(ctx, 2);
            sess.ensure_writable_txn();
            ctx.mem.commit();
            sess.unit_exit();
            assert sess.unit_depth() == 0;
            assert _stored(ctx, later.ensure_id()) == "2" , (
                "the write after the commit is saved without a re-run"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a write after a commit inside a read-only unit does not re-run it" {
    _write_commit_write(flush_first=False);
}


test "a write flushed before the commit still marks the unit a writer" {
    _write_commit_write(flush_first=True);
}
