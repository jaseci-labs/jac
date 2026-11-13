"""Failed unit entry unwinds its frame without settling an outer transaction."""

import os;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from uuid { uuid4 }
import from jaclang.data.store { TxnIsolation }
import from jaclang.runtime.exceptions { ReadOnlyRetry }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.session { RO_UNITS_ENV, unit_writes_recorded }
import from .test_read_path_isolation { _mk_session, _store }
import from .test_session_rollback { _as_any, _ctx, _sess, _loose, _stored }

test "failed run_request entry preserves the outer read-tier retry" {
    with TemporaryDirectory() as td, patch.dict(os.environ, {RO_UNITS_ENV: "1"}) {
        sess = _mk_session(td);
        key = "tests.failed_request_entry." + uuid4().hex;
        calls: list[int] = [];
        def body -> int {
            calls.append(1);
            return 7;
        }
        try {
            sess.unit_enter(key);
            sess.read_barrier();
            assert _store(sess).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY;
            raised = False;
            try {
                sess.run_request(body);
            } except ReadOnlyRetry as retry {
                raised = True;
                assert retry.unit_key == key;
            }
            assert raised , "entry must request a replay of the outer snapshot reads";
            assert not calls , "the nested body must not run on the old snapshot";
            assert sess.unit_depth() == 1 , "failed entry leaked a nested unit";
            assert sess._unit_stack == [(key, False)];
            assert sess._ro_units == 0 , "writer demotion must survive failed entry";
            assert unit_writes_recorded(key);
            assert not _store(sess).in_txn();

            resurfaced = False;
            try {
                sess.unit_exit();
            } except ReadOnlyRetry as retry {
                resurfaced = True;
                assert retry.unit_key == key;
            }
            assert resurfaced , "a caught nested retry must still replay the outer unit";
            assert sess.unit_depth() == 0;
            assert sess._unit_stack == [];

            sess.unit_enter(key);
            try {
                sess.read_barrier();
                assert _store(sess).txn_isolation() is TxnIsolation.SERIALIZABLE;
                assert sess.run_request(body) == 7;
                assert calls == [1];
                assert sess.unit_depth() == 1;
            } finally {
                sess.unit_exit();
            }
            assert sess.unit_depth() == 0;
        } finally {
            sess.close();
        }
    }
}


test "failed keyed or keyless entry restores counters at any depth" {
    with TemporaryDirectory() as td, patch.dict(os.environ, {RO_UNITS_ENV: "1"}) {
        sess = _mk_session(td);
        try {
            sess.read_scope_enter();
            sess.read_barrier();
            for nested in [False, True] {
                outer = "tests.failed_entry_outer." + uuid4().hex;
                if nested {
                    sess.unit_enter(outer);
                }
                for key in [None, "tests.failed_entry_inner." + uuid4().hex] {
                    for failure in [
                        RuntimeError("entry failed"),
                        KeyboardInterrupt()
                    ] {
                        stack = list(sess._unit_stack);
                        depth = sess.unit_depth();
                        ro_units = sess._ro_units;
                        raised = False;
                        with patch.object(sess, "_ensure_txn", side_effect=failure) {
                            try {
                                sess.unit_enter(key);
                            } except BaseException as error {
                                assert error is failure;
                                raised = True;
                            }
                        }
                        assert raised;
                        assert sess.unit_depth() == depth;
                        assert sess._unit_stack == stack;
                        assert sess._ro_units == ro_units;
                        assert _store(sess).txn_isolation()
                            is TxnIsolation.SNAPSHOT_READ_ONLY;
                    }
                }
                if nested {
                    sess.unit_exit();
                }
            }
            sess.read_scope_exit();
            assert not _store(sess).in_txn();
        } finally {
            sess.close();
        }
    }
}


test "failed nested entry leaves the outer writes for its final commit" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            anchor = _loose(ctx, 1);
            sess.commit();
            sess.unit_enter();
            _as_any(anchor.archetype).n = 2;
            sess.mark_dirty(anchor);
            sess.read_barrier();
            raised = False;
            with patch.object(
                sess, "_ensure_txn", side_effect=RuntimeError("entry failed")
            ) {
                try {
                    sess.run_request(lambda() { return 0; });
                } except RuntimeError {
                    raised = True;
                }
            }
            assert raised;
            assert sess.unit_depth() == 1;
            assert sess._unit_stack == [(None, False)];
            assert _store(sess).in_txn() , "failed entry must not abort the outer unit";
            assert _stored(ctx, anchor.ensure_id(), "n") == "1" , (
                "failed entry must not commit the outer unit"
            );
            sess.unit_exit();
            assert sess.unit_depth() == 0;
            assert _stored(ctx, anchor.ensure_id(), "n") == "2";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
