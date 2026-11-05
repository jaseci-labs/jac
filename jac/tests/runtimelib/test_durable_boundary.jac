"""A child session shares its parent's durable boundary, not other requests'."""

import asyncio;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from uuid { uuid4 }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.memory { Memory }
import from jaclang.server.session { Session }
import jaclang.server.sv_client as sv_client;
import from jaclang.runtime.exceptions { PartialCommitError }
import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface as Jac }
import from .test_session_rollback {
    _ctx,
    _sess,
    _loose,
    _stored,
    _as_any,
    _fail_commits
}

test "durable boundaries follow parent contexts across independent sessions" {
    with TemporaryDirectory() as td, TemporaryDirectory() as other_td {
        parent = _ctx(td);
        unrelated = _ctx(other_td);
        child = ExecutionContext(_parent=parent, _own_session=True);
        try {
            outer = _sess(parent);
            inner = _sess(child);
            separate = _sess(unrelated);
            assert outer is not inner;
            assert outer._durable_boundary is inner._durable_boundary;
            assert outer._durable_boundary is not separate._durable_boundary;
            assert outer._durable_boundary.current() == 0;
            inner.read_barrier();
            inner.commit();
            assert outer._durable_boundary.current() == 0 , "read-only commit is not durable work";
            inner._durable_boundary.mark();
            assert outer._durable_boundary.current() == 1;
            assert separate._durable_boundary.current() == 0;
        } finally {
            child.close();
            parent.close();
            unrelated.close();
        }
    }
}

test "in-memory units retain callback boundaries without a database" {
    mem = Memory();
    calls: list[int] = [];
    mem.unit_enter();
    mem.on_commit(lambda() { calls.append(1); });
    mem.commit();
    assert calls == [1] and mem.has_durable_boundary();
    mem.unit_committed();
    assert not mem.has_durable_boundary();
    mem.unit_exit();
    assert mem.unit_depth() == 0;
}

test "a lazily opened store starts a transaction on raw queries inside a unit" {
    with TemporaryDirectory() as td {
        sess = Session(base_path=td, target_path=td + "/lazy.jac");
        try {
            assert sess._store is None;
            sess.unit_enter();
            assert sess._store is None , "unit entry must preserve lazy store setup";
            store = sess.store;
            assert store is not None and not store.in_txn();
            store.rows("SELECT 1", {});
            assert store.in_txn();
            sess.unit_exit();
        } finally {
            sess.close();
        }
    }
}

test "durable nested or explicit work stops outer replay" {
    for variant in ["shared", "child", "explicit", "callback_error"] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _ctx(td);
            JacRuntime.exec_ctx = ctx;
            child = ExecutionContext(_parent=ctx, _own_session=True)
                if variant == "child"
                else ctx;
            try {
                sess = _sess(ctx);
                inner_session = _sess(child);
                parent = _loose(ctx, 1);
                sess.commit();
                calls: list[int] = [];
                effects: list[int] = [];
                ids: list[any] = [];
                faults: list[list[int]] = [];
                def outer -> int {
                    calls.append(1);
                    def inner -> int {
                        created = _loose(child, 42);
                        ids.append(created.ensure_id());
                        if variant == "explicit" {
                            Jac.on_commit(lambda() { effects.append(1); });
                        } elif variant == "callback_error" {
                            def failing_effect {
                                effects.append(1);
                                raise ValueError("callback failed after commit");
                            }
                            inner_session.on_commit(failing_effect);
                        } else {
                            inner_session.on_commit(lambda() { effects.append(1); });
                        }
                        return 0;
                    }
                    if variant == "explicit" {
                        inner();
                        Jac.commit();
                    } else {
                        inner_session.run_request(inner);
                    }
                    current = sess.get(parent.ensure_id());
                    assert current is not None;
                    _as_any(current.archetype).n += 1;
                    faults.append(_fail_commits(sess));
                    return _as_any(current.archetype).n;
                }
                raised = False;
                try {
                    sess.run_request(outer);
                } except PartialCommitError {
                    raised = True;
                }
                assert raised , variant;
                assert calls == [1] and effects == [1] , variant;
                assert faults == [[0]] and len(ids) == 1 , variant;
                assert _stored(child, ids[0], "n") == "42" , variant;
                assert _stored(ctx, parent.ensure_id(), "n") == "1" , variant;
            } finally {
                if child is not ctx {
                    child.close();
                }
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    }
}

test "cancellation after a nested commit never retries durable work" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            calls: list[int] = [];
            effects: list[int] = [];
            ids: list[any] = [];
            def outer {
                calls.append(1);
                def inner {
                    created = _loose(ctx, 42);
                    ids.append(created.ensure_id());
                    def cancel {
                        effects.append(1);
                        raise asyncio.CancelledError();
                    }
                    sess.on_commit(cancel);
                }
                sess.run_request(inner);
            }
            interrupted = False;
            try {
                sess.run_request(outer);
            } except asyncio.CancelledError {
                interrupted = True;
            }
            assert interrupted;
            assert calls == [1] and effects == [1] and len(ids) == 1;
            assert _stored(ctx, ids[0], "n") == "42";
            assert sess.unit_depth() == 0;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "cancelling an async commit waits until its durable outcome is known" {
    import threading;
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            anchor = _loose(ctx, 42);
            store: any = sess.store;
            real_commit = store.commit;
            started = threading.Event();
            release = threading.Event();
            def delayed_commit {
                if store.in_txn() {
                    started.set();
                    assert release.wait(10);
                }
                real_commit();
            }
            store.commit = delayed_commit;
            sess.unit_enter();
            async def run {
                task = asyncio.create_task(sess.acommit());
                assert await asyncio.to_thread(started.wait, 10);
                task.cancel();
                await asyncio.sleep(0);
                assert not task.done() , "cancellation returned before commit settled";
                release.set();
                cancelled = False;
                try {
                    await task;
                } except asyncio.CancelledError {
                    cancelled = True;
                }
                assert cancelled;
            }
            asyncio.run(run());
            store.commit = real_commit;
            assert _stored(ctx, anchor.ensure_id(), "n") == "42";
            assert sess.has_durable_boundary();
            sess.unit_exit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "a lost commit acknowledgement never retries possibly committed work" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            store: any = sess.store;
            real_commit = store.commit;
            fired: list[int] = [];
            ids: list[any] = [];
            def lost_ack {
                if not fired and store.in_txn() {
                    real_commit();
                    fired.append(1);
                    raise PgWireError(
                        {"C": "08006", "M": "connection lost after commit"}
                    );
                }
                real_commit();
            }
            store.commit = lost_ack;
            def body {
                created = _loose(ctx, 42);
                ids.append(created.ensure_id());
            }
            stopped = False;
            try {
                sess.run_request(body);
            } except PartialCommitError {
                stopped = True;
            }
            assert stopped;
            assert fired == [1] and len(ids) == 1;
            assert _stored(ctx, ids[0], "n") == "42";
            store.commit = real_commit;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

test "raw SQL committed by a nested unit also prevents outer replay" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            parent = _loose(ctx, 1);
            sess.commit();
            store = _as_any(sess.store);
            calls: list[int] = [];
            keys: list[str] = [];
            faults: list[list[int]] = [];
            def outer {
                calls.append(1);
                def inner {
                    key = uuid4().hex;
                    keys.append(key);
                    store.rows(
                        "INSERT INTO kv_state (key, value) VALUES (:k, 'v') RETURNING key",
                        {"k": key}
                    );
                }
                sess.run_request(inner);
                current = sess.get(parent.ensure_id());
                assert current is not None;
                _as_any(current.archetype).n += 1;
                if len(calls) == 1 {
                    faults.append(_fail_commits(sess));
                }
            }
            stopped = False;
            try {
                sess.run_request(outer);
            } except PartialCommitError {
                stopped = True;
            }
            assert stopped;
            assert calls == [1] and len(keys) == 1 and faults == [[0]];
            probe = _as_any(sess.store).new_session();
            try {
                rows = probe.rows(
                    "SELECT count(*) FROM kv_state WHERE key = :k", {"k": keys[0]}
                );
                assert int(rows[0][0]) == 1;
            } finally {
                probe.close();
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

obj RawLocalProvider {
    has keys: list[str] = [];

    def write -> int {
        mem: any = Jac.get_context().mem;
        key = uuid4().hex;
        self.keys.append(key);
        mem.store.rows(
            "INSERT INTO kv_state (key, value) VALUES (:k, 'v') RETURNING key",
            {"k": key}
        );
        return 1;
    }
}

test "local child function raw writes prevent the parent retry" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        provider = RawLocalProvider();
        sv_client.register_local("durable_test", provider);
        try {
            sess = _sess(ctx);
            parent = _loose(ctx, 1);
            _ = ctx.user_root;
            sess.commit();
            calls: list[int] = [];
            faults: list[list[int]] = [];
            async def child_context(
                target: object, parent_ctx: ExecutionContext, root_id: str
            ) -> ExecutionContext {
                return ExecutionContext(_parent=parent_ctx, _own_session=True);
            }
            def body {
                calls.append(1);
                asyncio.run(sv_client.call("durable_test", "write", {}));
                current = sess.get(parent.ensure_id());
                assert current is not None;
                _as_any(current.archetype).n += 1;
                if len(calls) == 1 {
                    faults.append(_fail_commits(sess));
                }
            }
            stopped = False;
            with patch("jaclang.runtime.prepared.application_of", return_value=True), patch.object(
                ExecutionContext, "for_target", side_effect=child_context
            ) {
                try {
                    sess.run_request(body);
                } except PartialCommitError {
                    stopped = True;
                }
            }
            assert stopped;
            assert calls == [1] and len(provider.keys) == 1 and faults == [[0]];
            probe = _as_any(sess.store).new_session();
            try {
                rows = probe.rows(
                    "SELECT count(*) FROM kv_state WHERE key = :k",
                    {"k": provider.keys[0]}
                );
                assert int(rows[0][0]) == 1;
            } finally {
                probe.close();
            }
        } finally {
            sv_client.unregister_local("durable_test");
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}

obj DurableRemoteResponse {
    has headers: dict[str, str] = {"Content-Type": "application/json"};

    def json -> dict[str, any] {
        return {"ok": True, "data": {"result": 1}};
    }
}

obj DurableRemoteClient {
    has calls: list[str] = [];

    def post(path: str, json: any, headers: any) -> DurableRemoteResponse {
        self.calls.append(path);
        return DurableRemoteResponse();
    }
}

test "remote writer dispatch prevents parent replay but a declared read does not" {
    for writer in [True, False] {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _ctx(td);
            JacRuntime.exec_ctx = ctx;
            remote = DurableRemoteClient();
            sv_client.register_test_client("durable_remote", remote);
            try {
                sess = _sess(ctx);
                anchor = _loose(ctx, 1);
                sess.commit();
                calls: list[int] = [];
                failures: list[list[int]] = [];
                def body -> int {
                    calls.append(1);
                    effects = ["Profile"] if writer else [];
                    assert asyncio.run(
                        sv_client.call(
                            "durable_remote", "read_or_write", {}, effects=effects
                        )
                    )
                        == 1;
                    current = sess.get(anchor.ensure_id());
                    assert current is not None;
                    _as_any(current.archetype).n += 1;
                    if len(calls) == 1 {
                        failures.append(_fail_commits(sess));
                    }
                    return _as_any(current.archetype).n;
                }
                stopped = False;
                try {
                    result = sess.run_request(body);
                    assert not writer and result == 2;
                } except PartialCommitError {
                    stopped = True;
                }
                assert stopped == writer;
                assert len(calls) == (1 if writer else 2);
                assert failures == [[0]];
                if writer {
                    assert len(remote.calls) == 1;
                }
            } finally {
                sv_client.clear_test_clients();
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    }
}


test "unit exit propagates an ambiguous commit acknowledgement" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            sess = _sess(ctx);
            store: any = sess.store;
            real_commit = store.commit;
            key = uuid4().hex;
            sess.unit_enter();
            store.rows(
                "INSERT INTO kv_state (key, value) VALUES (:k, 'v') RETURNING key",
                {"k": key}
            );
            def lost_ack {
                real_commit();
                raise PgWireError({"C": "08006", "M": "connection lost after commit"});
            }
            store.commit = lost_ack;
            stopped = False;
            try {
                sess.unit_exit();
            } except PartialCommitError {
                stopped = True;
            } finally {
                store.commit = real_commit;
            }
            assert stopped;
            probe = store.new_session();
            try {
                rows = probe.rows(
                    "SELECT count(*) FROM kv_state WHERE key = :k", {"k": key}
                );
                assert int(rows[0][0]) == 1;
            } finally {
                probe.close();
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
