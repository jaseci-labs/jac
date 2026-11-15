"""A write that did not happen must not report success.

The optimistic-concurrency machinery was wired but inert: `read_versions` and
`note_traversal_reads` recorded, `WriteConflict` existed with a retry loop and a
409 behind it, and `AnchorRow.version` was populated from `xmin` -- but nothing
ever raised, nothing incremented a version, and `_materialize` dropped the
version it loaded. Concurrent read-modify-writes silently kept the last one and
told every loser it had succeeded.

`xmin` cannot serve as the token either: it is a 32-bit transaction id that
wraps, and VACUUM FREEZE rewrites it to a constant, so two genuinely different
row versions can report the same number on a long-lived table.

These pin a real version column that advances on write, a conflicting write
that reports rather than vanishing, and a long-lived session that sees other
sessions' commits once its own transaction ends (jac#10287).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.exceptions { WriteConflict }
import from jaclang.server.session { Session }

node WCounter {
    has n: int = 0,
        tags: (list[str] | None) = None;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "wc_app.jac")
    );
}


test "a stored anchor carries a version that advances on write" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        cid: UUID;
        try {
            c = WCounter(n=1);
            root ++> c;
            ctx.mem.commit();
            cid = c.__jac__.id;
            store = ctx.mem.store;
            assert store is not None;
            first = store.rows(
                "SELECT version FROM anchors WHERE id = CAST(:i AS uuid)",
                {"i": str(cid)}
            )[0][0];
            c.n = 2;
            ctx.mem.mark_dirty(c.__jac__);
            ctx.mem.commit();
            second = store.rows(
                "SELECT version FROM anchors WHERE id = CAST(:i AS uuid)",
                {"i": str(cid)}
            )[0][0];
            assert int(second) > int(first) , (
                f"a write must advance the version: {first} -> {second}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


"""A reads the counter and ends its transaction, B commits n=99, and A goes on
by `mode`: "commit" or "rollback" name how A's transaction ended; "assign" and
"in place" also have A write over its stale copy, which must report a conflict.
Either way A then holds B's value, and an in-place edit on top of it is stored."""
def _after_other_commit(td: str, mode: str) {
    old = JacRuntime.exec_ctx;
    ctx1 = _ctx(td);
    JacRuntime.exec_ctx = ctx1;
    cid: UUID;
    try {
        c = WCounter(n=1, tags=([] if mode == "in place" else None));
        root ++> c;
        ctx1.mem.commit();
        cid = c.__jac__.id;
    } finally {
        JacRuntime.exec_ctx = old;
        ctx1.close();
    }
    ctxa = _ctx(td);
    JacRuntime.exec_ctx = ctxa;
    try {
        a = ctxa.mem.get(cid);
        assert a is not None;
        seen = _as_any(a).archetype.n;
        fetched = ctxa.mem.get_fetch_count();
        assert ctxa.mem.get(cid) is a and ctxa.mem.get_fetch_count() == fetched , (
            f"{mode}: a second read in the same transaction must come from memory"
        );
        if mode == "rollback" {
            _as_any(ctxa.mem)._rollback_txn();
        } else {
            ctxa.mem.commit();
        }

        JacRuntime.exec_ctx = old;
        ctxb = _ctx(td);
        JacRuntime.exec_ctx = ctxb;
        try {
            b = ctxb.mem.get(cid);
            assert b is not None;
            _as_any(b).archetype.n = 99;
            _as_any(b).archetype.tags = ["b"];
            ctxb.mem.mark_dirty(b);
            ctxb.mem.commit();
        } finally {
            ctxb.close();
        }

        JacRuntime.exec_ctx = ctxa;
        if mode in ["assign", "in place"] {
            if mode == "assign" {
                _as_any(a).archetype.n = seen + 1;
                ctxa.mem.mark_dirty(a);
            } else {
                _as_any(a).archetype.tags.append("a");
            }
            ctxa.mem.get(cid);
            raised = False;
            try {
                ctxa.mem.commit();
            } except WriteConflict {
                raised = True;
            }
            assert raised , (
                f"{mode}: a write over a version that moved must report a "
                "conflict, not silently overwrite the winner or vanish"
            );
            # Reported once, then gone: the next read must not flush it again.
            ctxa.mem.read_barrier();
        }
        assert ctxa.mem.get(cid) is a , f"{mode}: a held node was replaced";
        assert _as_any(a).archetype.n == 99 , f"{mode}: A still sees its stale copy";
        _as_any(a).archetype.tags.append("a");
        ctxa.mem.commit();
    } finally {
        JacRuntime.exec_ctx = old;
        ctxa.close();
    }
    ctxr = _ctx(td);
    JacRuntime.exec_ctx = ctxr;
    try {
        r = ctxr.mem.get(cid);
        assert r is not None and _as_any(r).archetype.tags == ["b", "a"] , (
            f"{mode}: A's in-place write over B's value was not stored"
        );
    } finally {
        JacRuntime.exec_ctx = old;
        ctxr.close();
    }
}


test "a write over a stale read reports instead of vanishing" {
    for mode in ["commit", "rollback", "assign", "in place"] {
        with TemporaryDirectory() as td {
            _after_other_commit(td, mode);
        }
    }
}


test "a session with no store keeps what it holds across a commit" {
    sess = Session();
    held = _as_any(WCounter(n=5).__jac__);
    held.persistent = True;
    hid = held.ensure_id();
    sess.__mem__[hid] = held;
    sess.commit();
    assert sess.batch_get([hid]) == {hid: held};
}
