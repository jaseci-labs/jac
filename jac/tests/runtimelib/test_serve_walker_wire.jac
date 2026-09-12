"""Wire contract for walker and function responses (#8906).

A walker spawn answers with the executed walker in `result` (its `has` fields
as the walk left them, plus the type markers) and the values it reported in
`reports`. The walker's own report list is never repeated inside `result`,
wherever the walker sits in the payload. A function answers with its return
value in `result`, and the only reports beside it are the ones walkers spawned
inside it produced.
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

test "a walker answers with its fields once and its reports beside them" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/walker/Outer", json={"tag": "t1"}).data;
        client.close();
        assert data["result"]["tag"] == "t1";
        assert data["result"]["_jac_archetype"] == "walker";
        assert "reports" not in data["result"];
        assert data["reports"] == [{"inner": True}, {"outer": "t1"}];
    }
}

test "a walker that never reports answers with the state its walk left" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/walker/CountThings", json={}).data;
        client.close();
        assert data["result"]["total"] == 1;
        assert "reports" not in data["result"];
        assert data["reports"] == [];
    }
}

test "a walker that reports itself serialises without its report list" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/walker/SelfReporter", json={}).data;
        client.close();
        assert data["result"]["tag"] == "me";
        assert "reports" not in data["result"];
        assert len(data["reports"]) == 1;
        assert data["reports"][0]["tag"] == "me";
        assert "reports" not in data["reports"][0];
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

test "a walker returned from a function carries its fields and no report copy" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        data = client.post("/function/spawn_and_return_walker", json={"tag": "q"}).data;
        client.close();
        assert data["result"]["tag"] == "q";
        assert "reports" not in data["result"];
        assert data["reports"] == [{"inner": True}, {"outer": "q"}];
    }
}
