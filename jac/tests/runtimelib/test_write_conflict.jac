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

These pin a real version column that advances on write, and a conflicting write
that reports rather than vanishing.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.exceptions { WriteConflict }

node WCounter {
    has n: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "wc_app.jac")
    );
}


def _seed(td: str) -> UUID {
    old = JacRuntime.exec_ctx;
    ctx = _ctx(td);
    JacRuntime.exec_ctx = ctx;
    try {
        c = WCounter(n=0);
        root ++> c;
        ctx.mem.commit();
        return c.__jac__.id;
    } finally {
        JacRuntime.exec_ctx = old;
        ctx.close();
    }
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


test "a write over a stale read reports instead of vanishing" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        cid: UUID;
        try {
            c = WCounter(n=1);
            root ++> c;
            ctx1.mem.commit();
            cid = c.__jac__.id;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        # Reader A loads the counter and holds its version.
        ctxa = _ctx(td);
        JacRuntime.exec_ctx = ctxa;
        try {
            a = ctxa.mem.get(cid);
            assert a is not None;
            seen = _as_any(a).archetype.n;

            # Writer B advances it out of band and commits first.
            JacRuntime.exec_ctx = old;
            ctxb = _ctx(td);
            JacRuntime.exec_ctx = ctxb;
            try {
                b = ctxb.mem.get(cid);
                assert b is not None;
                _as_any(b).archetype.n = 99;
                ctxb.mem.mark_dirty(b);
                ctxb.mem.commit();
            } finally {
                ctxb.close();
            }

            # A now writes on top of a version that has moved.
            JacRuntime.exec_ctx = ctxa;
            _as_any(a).archetype.n = seen + 1;
            ctxa.mem.mark_dirty(a);
            raised = False;
            try {
                ctxa.mem.commit();
            } except WriteConflict {
                raised = True;
            }
            assert raised , (
                "a write over a version that moved must report a conflict, "
                "not silently overwrite the winner"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctxa.close();
        }
    }
}

test "a pushed context does not shift a write onto the wrong session" {
    # End to end over a real store, which the dirty-set tests in
    # test_context_isolation cannot reach: a misattributed mark only becomes a
    # stale write-back, a spurious conflict or a lost write once a flush runs.
    # Both rows share one ambient layout (the caller is global, `bg` is pushed)
    # and differ only in which session loaded the copy that gets written, so
    # each pins one direction. For 'bg' the caller must stay clean and its
    # later commit must be a no-op rather than a write-back of the copy it
    # holds at the version it read. For 'caller' the pushed session must flush
    # nothing, or it bumps the version under the caller's real write.
    for (writer, want) in [('bg', 1), ('caller', 5)] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            cid = _seed(td);
            caller = _ctx(td);
            JacRuntime.exec_ctx = caller;
            try {
                held = caller.mem.get(cid);
                assert held is not None , (
                    f"{writer}: the caller must hold a copy that can go stale"
                );
                caller.mem.commit();

                bg = _ctx(td);
                token = JacRuntime.push_request_context(bg);
                try {
                    mine = bg.mem.get(cid);
                    assert mine is not None , f"{writer}: both sessions hold a copy";
                    target = mine if writer == 'bg' else held;
                    _as_any(target).archetype.n = want;

                    (owner, bystander) = (bg.mem, caller.mem)
                        if writer == 'bg'
                        else (caller.mem, bg.mem);
                    assert cid in owner._dirty , (
                        f"{writer}: the write belongs to the session holding the "
                        "written copy"
                    );
                    assert cid not in bystander._dirty , (
                        f"{writer}: a session that wrote nothing must flush nothing"
                    );
                    bg.mem.commit();
                } finally {
                    JacRuntime.reset_request_context(token);
                    bg.close();
                }

                # Reads flush what the session was told it owes, so a leaked mark
                # fails work that only reads, on an anchor it never touched.
                caller.mem.read_barrier();
                caller.mem.commit();
            } finally {
                JacRuntime.exec_ctx = old;
                caller.close();
            }
            verify = _ctx(td);
            JacRuntime.exec_ctx = verify;
            try {
                got = verify.mem.get(cid);
                assert got is not None;
                assert _as_any(got).archetype.n == want , (
                    f"{writer}: the write must reach the store intact"
                );
            } finally {
                JacRuntime.exec_ctx = old;
                verify.close();
            }
        }
    }
}
