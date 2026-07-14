"""Tier 2 (abort-on-error) tests at the serve boundary (#6619).

A walker that raises must not half-mutate the graph: its creates,
connects, and deletes are discarded — both from what later requests
observe in-process and from what survives a restart. A successful
walker's work still persists (positive control).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        str((Path(FIXTURES) / "abort_app.jac").resolve()), base_path=base_path
    );
}


def count_items(client: JacTestClient) -> int {
    response = client.post("/walker/CountItems", json={});
    assert response.ok , f"CountItems failed: {response.json()}";
    reports = response.data.get("reports", []);
    assert reports , f"CountItems returned no reports: {response.data}";
    return reports[0]["count"];
}


test "failed walker's create does not appear to later requests" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_a", "pw12345").ok;
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
        assert client.register_user("abort_b", "pw12345").ok;
        client.post("/walker/CreateAndFail", json={});
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_b", "pw12345").ok;
        assert count_items(reopened) == 0 , (
            "a failed walker's create was persisted across restart"
        );
        reopened.close();
    }
}


test "failed walker's delete is rolled back" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_c", "pw12345").ok;
        ok_response = client.post("/walker/CreateOk", json={"name": "survivor"});
        assert ok_response.ok , f"CreateOk failed: {ok_response.json()}";
        assert count_items(client) == 1;
        client.post("/walker/DeleteAndFail", json={});
        assert count_items(client) == 1 , (
            "a failed walker's delete destroyed committed data in-process"
        );
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_c", "pw12345").ok;
        assert count_items(reopened) == 1 , (
            "a failed walker's delete destroyed committed data durably"
        );
        reopened.close();
    }
}


test "successful walker still persists (positive control)" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client.register_user("abort_d", "pw12345").ok;
        assert client.post("/walker/CreateOk", json={"name": "kept"}).ok;
        assert count_items(client) == 1;
        client.close();
        reopened = make_client(tmpdir);
        assert reopened.login("abort_d", "pw12345").ok;
        assert count_items(reopened) == 1 , "committed work must survive restart";
        reopened.close();
    }
}
