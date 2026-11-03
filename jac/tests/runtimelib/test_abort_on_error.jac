"""Tier 2 (abort-on-error) tests at the serve boundary (#6619).

A walker that raises must not half-mutate the graph: its creates,
connects, and deletes are discarded — both from what later requests
observe in-process and from what survives a restart. A successful
walker's work still persists (positive control).
"""

import asyncio;
import json;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
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


"""An answer to a failed late write is final on every endpoint, so a retry with
the same key replays it. A failed first commit saved nothing, so a retry runs."""
test "a failed late write replays under its idempotency key; a failed first commit re-runs" {
    import from jaclang.server.endpoints.colocated {
        _function_callback,
        _walker_callback
    }
    import from jaclang.server.serving.app { transport_to_response }
    import from jaclang.server.serving.datatypes { Headers, JSONResponse, Request }
    import from jaclang.server.transport { TransportResponse }
    bad = f"a{chr(0)}b";
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
            walker_cb = _walker_callback(server, "abort", "LateWrite", intro, False);
            function_cb = _function_callback(
                server, "abort", "late_note", intro, False
            );
            for (label, send) in (
                ("walker", by_route("/walker/LateWrite")),
                ("function", by_route("/function/late_note")),
                ("colocated walker", by_callback(walker_cb)),
                ("colocated function", by_callback(function_cb))
            ) {
                mod.runs.clear();
                answers = [send({"late": bad}, f"late-{label}") for _ in range(3)];
                assert all(a == answers[0] for a in answers) , f"{label}: {answers}";
                assert answers[0][0] == 500 , f"{label}: {answers[0]}";
                assert "LATE_WRITE_FAILED" in answers[0][1] , f"{label}: {answers[0]}";
                assert len(mod.runs) == 1 , (
                    f"{label}: a retry re-ran the saved work, {len(mod.runs)} runs"
                );
            }
            for (label, send) in (
                ("walker", by_route("/walker/LateWrite")),
                ("colocated walker", by_callback(walker_cb))
            ) {
                mod.runs.clear();
                answers = [send({"first": bad}, f"first-{label}") for _ in range(2)];
                assert answers[0][0] == 500 , f"{label}: {answers[0]}";
                assert len(mod.runs) == 2 , (
                    f"{label}: nothing was saved, so a retry must run: {len(mod.runs)}"
                );
            }
        } finally {
            client.close();
        }
    }
}
