"""Nested retries preserve the outer committed boundary and reset on abort."""

import from tempfile { TemporaryDirectory }
import from jaclang.runtime.exceptions { WriteConflict }
import from jaclang.runtime.runtime { JacRuntime }
import from .test_session_rollback {
    _as_any,
    _ctx,
    _sess,
    _loose,
    _stored,
    _fail_commits
}

test "nested retries preserve the outer commit boundary and abort reopens replay" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            anchor = _loose(ctx, 1);
            sess.commit();
            sess.unit_enter();
            sess.unit_committed();
            calls: list[int] = [];
            def nested -> int {
                calls.append(1);
                current = sess.get(anchor.ensure_id());
                assert current is not None;
                _as_any(current.archetype).n += 1;
                return _as_any(current.archetype).n;
            }
            left = _fail_commits(sess);
            assert sess.run_request(nested) == 2;
            assert left == [0];
            assert calls == [1, 1];
            assert sess.unit_depth() == 1;
            current = sess.get(anchor.ensure_id());
            assert current is not None;
            _as_any(current.archetype).n = 3;
            left = _fail_commits(sess);
            sess.commit();
            assert left == [0];
            assert _stored(ctx, anchor.ensure_id(), "n") == "3";
            sess.abort();
            current = sess.get(anchor.ensure_id());
            assert current is not None;
            _as_any(current.archetype).n = 4;
            left = _fail_commits(sess);
            raised = False;
            try {
                sess.commit();
            } except WriteConflict {
                raised = True;
            }
            assert raised , "an aborted unit must replay its next read decisions";
            assert left == [0];
            assert _stored(ctx, anchor.ensure_id(), "n") == "3";
            sess.abort();
            sess.unit_exit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
