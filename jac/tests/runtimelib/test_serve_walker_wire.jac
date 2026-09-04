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

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        str((Path(FIXTURES) / "serve_walker_wire.jac").resolve()), base_path=base_path
    );
}

def auth_headers(client: JacTestClient) -> dict[str, str] {
    client.post(
        "/user/register",
        json={
            "identities": [{"type": "username", "value": "wire"}],
            "credential": {"type": "password", "password": "secret123"}
        }
    );
    login = client.post(
        "/user/login",
        json={
            "identity": {"type": "username", "value": "wire"},
            "credential": {"type": "password", "password": "secret123"}
        }
    );
    return {"Authorization": f"Bearer {login.data['token']}"};
}

test "a walker answers with an empty result and its reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            hdr = auth_headers(client);
            data = client.post("/walker/Outer", json={"tag": "t1"}, headers=hdr).data;
            assert data
                == {"result": {}, "reports": [{"inner": True}, {"outer": "t1"}]};
        } finally {
            client.close();
        }
    }
}

test "a walker that never reports answers with nothing" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            hdr = auth_headers(client);
            client.post("/walker/Seed", json={"count": 2}, headers=hdr);
            data = client.post(
                "/walker/CountThings", json={"prefix": "t"}, headers=hdr
            ).data;
            assert data == {"result": {}, "reports": []};
        } finally {
            client.close();
        }
    }
}

test "a function answers with its return value and no reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            hdr = auth_headers(client);
            data = client.post(
                "/function/list_things", json={"n": 2}, headers=hdr
            ).data;
            assert data
                == {
                    "result": [{"name": "t0", "idx": 0}, {"name": "t1", "idx": 1}],
                    "reports": []
                };
            data = client.post("/function/nothing", json={}, headers=hdr).data;
            assert data == {"result": None, "reports": []};
        } finally {
            client.close();
        }
    }
}

test "a walker spawned inside a function reports through the function" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            hdr = auth_headers(client);
            data = client.post(
                "/function/spawn_inside", json={"tag": "z"}, headers=hdr
            ).data;
            assert data
                == {
                    "result": {"tag": "z", "seen": 2},
                    "reports": [{"inner": True}, {"outer": "z"}]
                };
        } finally {
            client.close();
        }
    }
}

test "a walker returned from a function is empty on the wire" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            hdr = auth_headers(client);
            data = client.post(
                "/function/spawn_and_return_walker", json={"tag": "q"}, headers=hdr
            ).data;
            assert data == {"result": {}, "reports": [{"inner": True}, {"outer": "q"}]};
        } finally {
            client.close();
        }
    }
}
