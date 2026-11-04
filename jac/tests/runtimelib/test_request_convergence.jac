"""Serialization conflicts replay a unit's read decisions, not just its writes.

The rendezvous forces two real request transactions to read an empty graph
before either inserts. Postgres rejects one; its replay must find the winner.
The remaining cases cover the library and unit-exit replay boundaries.
"""

import asyncio;
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.exceptions { WriteConflict }
import from jaclang.server.request_scope { RequestScope }
import from .test_session_rollback {
    _as_any,
    _ctx,
    _sess,
    _loose,
    _stored,
    _fail_commits,
    _vote_app,
    _spawn,
    _without_read_tier,
    _restore_read_tier
}

test "request loop: two find-or-creates converge after a real predicate conflict" {
    import threading;
    prior = _without_read_tier();
    try {
        with TemporaryDirectory() as td {
            (exec_mgr, walkers, mod) = _vote_app(td);
            assert _spawn(exec_mgr, walkers["CountProfiles"]).get("reports") == [0];
            mod.profile_gate = threading.Barrier(2);
            ambient = JacRuntime.get_context();
            async def one -> any {
                with RequestScope.open(
                    ambient.base_path_dir, ambient.full_target_path
                ) {
                    return await exec_mgr.spawn_walker(
                        walkers["EnsureProfile"], {}, "voter"
                    );
                }
            }
            async def both -> any {
                return await asyncio.gather(one(), one());
            }
            results = _as_any(asyncio.run(both()));
            assert all("error" not in r for r in results) , f"{results}";
            assert results[0]["reports"] == results[1]["reports"] , (
                "a serialization retry must re-read the winner, not insert its "
                f"own duplicate: {results}"
            );
            count = _spawn(exec_mgr, walkers["CountProfiles"]);
            assert count.get("reports") == [1] , f"duplicates committed: {count}";
        }
    } finally {
        _restore_read_tier(prior);
    }
}


test "unit exit hands a serialization conflict to its caller without replaying writes" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            anchor = _loose(ctx, 1);
            sess = _sess(ctx);
            sess.commit();
            sess.unit_enter();
            _as_any(anchor.archetype).n = 2;
            sess.mark_dirty(anchor);
            left = _fail_commits(sess);
            conflicted = False;
            try {
                sess.unit_exit();
            } except WriteConflict {
                conflicted = True;
            }
            assert left == [0] , "the conflict never fired";
            assert conflicted , "unit_exit replayed writes without their read predicates";
            assert _stored(ctx, anchor.ensure_id(), "n") == "1";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "run_request re-runs the body after a serialization failure at commit" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            anchor = _loose(ctx, 1);
            sess = _sess(ctx);
            sess.commit();
            left = _fail_commits(sess);
            calls: list[int] = [];
            def body -> int {
                calls.append(1);
                current = sess.get(anchor.ensure_id());
                assert current is not None;
                _as_any(current.archetype).n += 1;
                return _as_any(current.archetype).n;
            }
            assert sess.run_request(body) == 2;
            assert left == [0] , "the conflict never fired";
            assert len(calls) == 2 , "only the writes were replayed";
            assert _stored(ctx, anchor.ensure_id(), "n") == "2";
            assert sess.unit_depth() == 0 , "run_request leaked its unit";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
