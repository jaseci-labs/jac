"""Tier 2 (abort-on-error) tests at the serve boundary (#6619).

A walker that raises must not half-mutate the graph: its creates,
connects, and deletes are discarded — both from what later requests
observe in-process and from what survives a restart. A successful
walker's work still persists (positive control).
"""

import asyncio;
import json;
import os;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.server.session { RO_UNITS_ENV }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def _as_any(v: any) -> any {
    return v;
}


def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        str((Path(FIXTURES) / "abort_app.jac").resolve()), base_path=base_path
    );
}


def count_items(client: JacTestClient) -> int {
    response = client.post("/walker/CountItems", json={});
    assert response.ok , f"CountItems failed: {response.json()}";
    reports = _as_any(response.data).get("reports", []);
    assert reports , f"CountItems returned no reports: {response.data}";
    return reports[0]["count"];
}


test "failed walker's create does not appear to later requests" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_a", "pw12345_Secure1").ok;
        fail_response = client.post("/walker/CreateAndFail", json={});
        assert (not fail_response.ok) or ("error" in (fail_response.json() or {})) , "CreateAndFail should surface an error";
        assert count_items(client) == 0 , (
            "a failed walker's create leaked into a later request"
        );
        client.close();
    }
}


test "failed walker's create does not survive a restart" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_b", "pw12345_Secure1").ok;
        client.post("/walker/CreateAndFail", json={});
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_b", "pw12345_Secure1").ok;
        assert count_items(reopened) == 0 , (
            "a failed walker's create was persisted across restart"
        );
        reopened.close();
    }
}


test "failed walker's delete is rolled back" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_c", "pw12345_Secure1").ok;
        ok_response = client.post("/walker/CreateOk", json={"name": "survivor"});
        assert ok_response.ok , f"CreateOk failed: {ok_response.json()}";
        assert count_items(client) == 1;
        client.post("/walker/DeleteAndFail", json={});
        assert count_items(client) == 1 , (
            "a failed walker's delete destroyed committed data in-process"
        );
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_c", "pw12345_Secure1").ok;
        assert count_items(reopened) == 1 , (
            "a failed walker's delete destroyed committed data durably"
        );
        reopened.close();
    }
}


test "successful walker still persists (positive control)" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_d", "pw12345_Secure1").ok;
        assert client.post("/walker/CreateOk", json={"name": "kept"}).ok;
        assert count_items(client) == 1;
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_d", "pw12345_Secure1").ok;
        assert count_items(reopened) == 1 , "committed work must survive restart";
        reopened.close();
    }
}

test "cancelled durable request returns the same final response for its idempotency key" {
    import threading;
    import from jaclang.server.endpoints.colocated { _walker_callback }
    import from jaclang.server.serving.app { transport_to_response }
    import from jaclang.server.serving.datatypes { Headers, JSONResponse, Request }
    import from jaclang.server.transport { TransportResponse }
    prior = os.environ.get(RO_UNITS_ENV);
    os.environ[RO_UNITS_ENV] = "0";
    try {
        with TemporaryDirectory() as td {
            client = make_client(td);
            try {
                assert client.register_user("cancel_durable", "pw12345_Secure1").ok;
                server = client.server;
                intro = server.introspector;
                mod = sys.modules[intro.target("CancelDurable").__module__];
                mod.runs.clear();
                mod.late_runs.clear();
                mod.cancel_started = threading.Event();
                mod.cancel_release = threading.Event();
                callback = _walker_callback(
                    server, "abort", "CancelDurable", intro, False
                );
                def request -> Request {
                    return Request(
                        method="POST",
                        headers=Headers([("X-Jac-Idempotency-Key", "cancel-durable")]),
                        body=b"{}"
                    );
                }
                async def cancelled -> any {
                    with server.request_scope() {
                        task = asyncio.create_task(callback(request()));
                        try {
                            assert await asyncio.to_thread(mod.cancel_started.wait, 10);
                            task.cancel();
                            await asyncio.sleep(0);
                            assert not task.done();
                        } finally {
                            mod.cancel_release.set();
                        }
                        return await task;
                    }
                }
                async def replay -> any {
                    with server.request_scope() {
                        return await callback(request());
                    }
                }
                first = _as_any(asyncio.run(cancelled()));
                second = _as_any(asyncio.run(replay()));
                if isinstance(first, TransportResponse) {
                    first = transport_to_response(first);
                }
                if isinstance(second, TransportResponse) {
                    second = transport_to_response(second);
                }
                assert isinstance(first, JSONResponse)
                    and isinstance(second, JSONResponse);
                assert first.status_code == 500 and second.status_code == 500;
                assert first.content == second.content;
                assert "FAILED_AFTER_COMMIT" in json.dumps(first.content);
                assert mod.runs == [1] and mod.late_runs == [1];
            } finally {
                client.close();
            }
        }
    } finally {
        if prior is None {
            os.environ.pop(RO_UNITS_ENV, None);
        } else {
            os.environ[RO_UNITS_ENV] = prior;
        }
    }
}


obj LateCase {
    has label: str,
        via: str = "walker",
        body: dict[str, any] = {},
        own_session: bool = False,
        read_tier: bool = False,
        status: int = 500,
        code: str = "FAILED_AFTER_COMMIT",
        runs: int = 1,
        callbacks: int = 1,
        saved: int = 1;
}


"""A failure after a request's first commit is its final answer: each row is sent
twice with one key, the walker never re-runs and the retry replays the answer, while
a callback's error from another database connection stays logged, as does one from
the walker's own commit(), before that first commit. A failed first commit saved
nothing, so its retry runs."""
test "a failure after the first commit is answered once and replayed, never re-run" {
    import from jaclang.server.endpoints.colocated {
        _function_callback,
        _walker_callback
    }
    import from jaclang.server.serving.app { transport_to_response }
    import from jaclang.server.serving.datatypes { Headers, JSONResponse, Request }
    import from jaclang.server.transport { TransportResponse }
    bad = f"a{chr(0)}b";
    refused = {"late": bad, "status": 429};
    cases = [
        LateCase("clean", status=200, code="", saved=2),
        LateCase("nested durable conflict", body={"fault": "nested_serial"}, saved=2),
        LateCase("child durable conflict", body={"fault": "child_serial"}, saved=0),
        LateCase(
            "explicit durable conflict", body={"fault": "explicit_serial"}, saved=1
        ),
        LateCase("bad late write, after respond(429)", body=refused),
        LateCase("function", via="function", body=refused),
        # Colocated callbacks run off this user's root, so its count stays put.
        LateCase("colocated walker", via="colocated walker", body=refused, saved=0),
        LateCase("colocated function", via="colocated function", body=refused, saved=0),
        LateCase("late write loses to a rival", body={"fault": "rival"}),
        LateCase("error on this connection", body={"fault": "own_db"}),
        LateCase("wrapped error on this connection", body={"fault": "wrapped_db"}),
        LateCase(
            "error raised while handling one on this connection",
            body={"fault": "raised_in_except"}
        ),
        LateCase(
            "error on this connection from the walker's own commit()",
            body={"fault": "own_db", "commit_first": True},
            status=200,
            code=""
        ),
        LateCase(
            "conflict from the walker's own commit()",
            body={"fault": "conflict", "commit_first": True},
            status=200,
            code=""
        ),
        LateCase(
            "error on another connection",
            body={"fault": "other_db"},
            status=200,
            code=""
        ),
        LateCase("conflict in the callback", body={"fault": "conflict"}),
        LateCase(
            "read tier retry in the callback",
            body={"fault": "read_tier"},
            status=200,
            code=""
        ),
        LateCase(
            "a callback's callback is dropped with the failed write",
            body={"fault": "chain", "late": bad},
            own_session=True
        ),
        LateCase("getter raises while serializing", via="peek", callbacks=0),
        LateCase(
            "late write on the read tier fails after callback ran",
            via="read tier",
            read_tier=True,
            saved=0
        ),
        LateCase(
            "first commit fails",
            body={"first": bad},
            own_session=True,
            code="EXECUTION_ERROR",
            runs=2,
            callbacks=0,
            saved=0
        ),
        LateCase(
            "first commit fails, colocated",
            via="colocated walker",
            body={"first": bad},
            code="EXECUTION_ERROR",
            runs=2,
            callbacks=0,
            saved=0
        )
    ];
    async def own_session_for(target: object, parent: any, user_root_id: str) -> any {
        context = ExecutionContext(
            _parent=parent, _own_session=True, full_target_path=parent.full_target_path
        );
        await context.aset_user_root(user_root_id);
        return context;
    }
    prior = os.environ.get(RO_UNITS_ENV);
    real_for_target = ExecutionContext.for_target;
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            assert client.register_user("abort_e", "pw12345_Secure1").ok;
            server = client.server;
            intro = server.introspector;
            mod = sys.modules[intro.target("LateWrite").__module__];
            def by_route(path: str) -> Callable {
                def send(body: dict[str, any], key: str) -> tuple[int, str] {
                    got = client.post(
                        path, json=body, headers={"X-Jac-Idempotency-Key": key}
                    );
                    return (got.status_code, json.dumps(got.json()));
                }
                return send;
            }
            def by_callback(callback: any) -> Callable {
                def send(body: dict[str, any], key: str) -> tuple[int, str] {
                    request = Request(
                        method="POST",
                        headers=Headers([("X-Jac-Idempotency-Key", key)]),
                        body=json.dumps(body).encode()
                    );
                    async def scoped -> any {
                        with server.request_scope() {
                            return await callback(request);
                        }
                    }
                    got = _as_any(asyncio.run(scoped()));
                    if isinstance(got, TransportResponse) {
                        got = transport_to_response(got);
                    }
                    assert isinstance(got, JSONResponse) , f"{got}";
                    return (got.status_code, json.dumps(got.content));
                }
                return send;
            }
            senders = {
                "walker": by_route("/walker/LateWrite"),
                "function": by_route("/function/late_note"),
                "peek": by_route("/walker/LatePeek"),
                "read tier": by_route("/walker/LateFromReadTier"),
                "colocated walker": by_callback(
                    _walker_callback(server, "abort", "LateWrite", intro, False)
                ),
                "colocated function": by_callback(
                    _function_callback(server, "abort", "late_note", intro, False)
                )
            };
            for row in cases {
                os.environ[RO_UNITS_ENV] = "1" if row.read_tier else "0";
                before = count_items(client);
                mod.runs.clear();
                mod.late_runs.clear();
                if row.own_session {
                    _as_any(ExecutionContext).for_target = own_session_for;
                }
                try {
                    answers = [senders[row.via](row.body, row.label) for _ in range(2)];
                } finally {
                    _as_any(ExecutionContext).for_target = real_for_target;
                }
                assert answers[0] == answers[1] , f"{row.label}: {answers}";
                assert answers[0][0] == row.status , f"{row.label}: {answers[0]}";
                assert row.code in answers[0][1] , f"{row.label}: {answers[0]}";
                assert len(mod.runs) == row.runs , f"{row.label}: ran {len(mod.runs)}";
                assert len(mod.late_runs) == row.callbacks , (
                    f"{row.label}: callback ran {len(mod.late_runs)} times"
                );
                saved = count_items(client) - before;
                assert saved == row.saved , f"{row.label}: saved {saved}";
            }
        } finally {
            if prior is None {
                os.environ.pop(RO_UNITS_ENV, None);
            } else {
                os.environ[RO_UNITS_ENV] = prior;
            }
            client.close();
        }
    }
}
