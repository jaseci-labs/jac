"""Wire contract for walker and function responses.

A walker's `has` fields are its request and `report` is its response, so a
walker answers with an empty `result` beside its `reports`, wherever the
walker sits in the payload. A function answers with its return value in
`result`, and the only reports beside it are the ones walkers spawned inside
it produced.
"""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURE = str(
         (Path(__file__).parent / "fixtures" / "serve_walker_wire.jac").resolve()
     );

def make_client(base_path: str) -> JacTestClient {
    client = JacTestClient.from_file(FIXTURE, base_path=base_path);
    client.register_user("wire", "secret123");
    return client;
}

test "a walker answers with an empty result and its reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/walker/Outer", json={"tag": "t1"}).data;
        client.close();
        assert data["result"] == {};
        assert data["reports"] == [{"inner": True}, {"outer": "t1"}];
    }
}

test "a walker that never reports answers with nothing" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/walker/CountThings", json={}).data;
        client.close();
        assert data["result"] == {};
        assert data["reports"] == [];
    }
}

test "a function answers with its return value and no reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        listed = client.post("/function/list_things", json={"n": 2}).data;
        empty = client.post("/function/nothing", json={}).data;
        client.close();
        assert listed["result"] == [{"name": "t0", "idx": 0}, {"name": "t1", "idx": 1}];
        assert listed["reports"] == [];
        assert empty["result"] is None;
        assert empty["reports"] == [];
    }
}

test "a walker spawned inside a function reports through the function" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/function/spawn_inside", json={"tag": "z"}).data;
        client.close();
        assert data["result"] == {"tag": "z", "seen": 2};
        assert data["reports"] == [{"inner": True}, {"outer": "z"}];
    }
}

test "a walker returned from a function is empty on the wire" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/function/spawn_and_return_walker", json={"tag": "q"}).data;
        client.close();
        assert data["result"] == {};
        assert data["reports"] == [{"inner": True}, {"outer": "q"}];
    }
}
