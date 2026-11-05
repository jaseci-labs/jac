"""A committed callback keeps write retries, without replaying irreversible work."""

import from tempfile { TemporaryDirectory }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.exceptions { PartialCommitError }
import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface as Jac }
import from .test_session_rollback {
    _as_any,
    _ctx,
    _sess,
    _loose,
    _stored,
    _fail_commits
}

def check_callback(variant: str, failures: int = 1, outer_conflict: bool = False) {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        child = ExecutionContext(_parent=ctx, _own_session=True)
            if variant == "child"
            else ctx;
        try {
            sess = _sess(ctx);
            worker = _sess(child);
            parent = _loose(ctx, 0);
            sess.commit();
            outer_calls: list[int] = [];
            body_calls: list[int] = [];
            callback_calls: list[int] = [];
            ids: list[any] = [];
            left = [failures];
            def body -> int {
                body_calls.append(1);
                ids.append(_loose(child, 7).ensure_id());
                def callback {
                    callback_calls.append(1);
                    ids.append(_loose(child, 42).ensure_id());
                    store = _as_any(worker.store);
                    real_upsert = store.upsert;
                    def failing_upsert(rows: any) -> any {
                        if left[0] > 0 {
                            left[0] -= 1;
                            store.rollback();
                            raise PgWireError(
                                {"C": "40001", "M": "injected callback flush conflict"}
                            );
                        }
                        return real_upsert(rows);
                    }
                    store.upsert = failing_upsert;
                    try {
                        worker.read_barrier();
                    } finally {
                        store.upsert = real_upsert;
                    }
                }
                worker.on_commit(callback);
                return 7;
            }
            def outer -> int {
                outer_calls.append(1);
                result = worker.run_request(body)
                    if variant in ["shared", "child"]
                    else body();
                if variant == "explicit" {
                    Jac.commit();
                }
                if outer_conflict {
                    current = sess.get(parent.ensure_id());
                    assert current is not None;
                    _as_any(current.archetype).n = 1;
                    _fail_commits(sess);
                }
                return result;
            }
            partial = False;
            result: any = None;
            try {
                result = sess.run_request(outer);
            } except PartialCommitError {
                partial = True;
            }
            assert outer_calls == [1] and body_calls == [1] and callback_calls == [1];
            assert left == [0] and len(ids) == 2;
            persisted = [_stored(child, id, "n") for id in ids];
            if failures > 1 {
                assert partial , "exhausted callback writes must not report success";
                assert persisted == ["7", None];
            } elif outer_conflict {
                assert partial , "outer replay must not repeat committed nested work";
                assert persisted == ["7", "42"];
            } else {
                assert not partial and result == 7;
                assert persisted == ["7", "42"];
            }
            assert _stored(ctx, parent.ensure_id(), "n") == "0";
        } finally {
            if child is not ctx {
                child.close();
            }
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "callback boundary request writes survive serialization" {
    check_callback("request");
}

test "callback boundary explicit commits retain write retries" {
    check_callback("explicit");
}

test "callback boundary shared nested commits retain write retries" {
    check_callback("shared");
}

test "callback boundary independent child commits retain write retries" {
    check_callback("child");
}

test "callback boundary exhausted writes fail without repeating work" {
    check_callback("request", failures=2);
}

test "callback boundary exhausted nested writes fail without repeating work" {
    check_callback("shared", failures=2);
}

test "callback boundary completed nested writes survive an outer conflict" {
    check_callback("shared", failures=0, outer_conflict=True);
}

test "callback boundary child partial failure reaches its parent" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        child = ExecutionContext(_parent=ctx, _own_session=True);
        try {
            sess = _sess(ctx);
            other = _sess(child);
            parent = _loose(child, 0);
            other.commit();
            body_calls: list[int] = [];
            callback_calls: list[int] = [];
            child_calls: list[int] = [];
            ids: list[any] = [];
            faults: list[list[int]] = [];
            def body {
                body_calls.append(1);
                ids.append(_loose(ctx, 7).ensure_id());
                def callback {
                    callback_calls.append(1);
                    def nested {
                        def inner {
                            child_calls.append(1);
                            ids.append(_loose(child, 42).ensure_id());
                        }
                        other.run_request(inner);
                        current = other.get(parent.ensure_id());
                        assert current is not None;
                        _as_any(current.archetype).n = 1;
                        faults.append(_fail_commits(other));
                    }
                    other.run_request(nested);
                }
                sess.on_commit(callback);
            }
            partial = False;
            try {
                sess.run_request(body);
            } except PartialCommitError {
                partial = True;
            }
            assert partial , "a failed child callback must not report parent success";
            assert body_calls == [1] and callback_calls == [1] and child_calls == [1];
            assert faults == [[0]] and len(ids) == 2;
            assert [_stored(child, id, "n") for id in ids] == ["7", "42"];
            assert _stored(child, parent.ensure_id(), "n") == "0";
        } finally {
            child.close();
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
