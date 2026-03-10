"""Tests for JacTestClient - the port-free test client."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}

def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api.jac"), base_path=base_path
    );
}

# --- Basic tests ---
test "client creation" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client is not None;
        assert client._jac_file.endswith("serve_api.jac");
        client.close();
    }
}

test "client file not found" {
    with TemporaryDirectory() as tmpdir {
        raised = False;
        try {
            JacTestClient.from_file("nonexistent.jac", base_path=tmpdir);
        } except FileNotFoundError {
            raised = True;
        }
        assert raised , "Expected FileNotFoundError for missing file";
    }
}

test "get root endpoint" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/");
        assert response.ok;
        assert response.status_code == 200;
        assert "endpoints" in response.data;
        client.close();
    }
}

test "register user" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.register_user("testuser", "testpass");
        assert response.ok;
        assert response.status_code == 201;
        assert response.data["username"] == "testuser";
        assert "token" in response.data;
        assert "root_id" in response.data;
        assert client._auth_token == response.data["token"];
        client.close();
    }
}

test "login user" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("loginuser", "loginpass");
        client.clear_auth();
        response = client.login("loginuser", "loginpass");
        assert response.ok;
        assert response.data["username"] == "loginuser";
        assert client._auth_token is not None;
        client.close();
    }
}

test "auth token management" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        assert client._auth_token is None;
        client.set_auth_token("test-token");
        assert client._auth_token == "test-token";
        client.clear_auth();
        assert client._auth_token is None;
        client.close();
    }
}

test "authentication required" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/protected");
        assert not response.ok;
        assert "Unauthorized" in str(response.data);
        client.close();
    }
}

test "list functions with auth" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("funcuser", "pass");
        response = client.get("/functions");
        assert response.ok;
        assert "functions" in response.data;
        assert "add_numbers" in response.data["functions"];
        client.close();
    }
}

test "call function" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("calluser", "pass");
        response = client.post("/function/add_numbers", json={"a": 10, "b": 25});
        assert response.ok;
        assert response.data["result"] == 35;
        client.close();
    }
}

test "list walkers" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("walkuser", "pass");
        response = client.get("/walkers");
        assert response.ok;
        assert "walkers" in response.data;
        assert "CreateTask" in response.data["walkers"];
        client.close();
    }
}

test "spawn walker" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        client.register_user("spawnuser", "pass");
        response = client.post(
            "/walker/CreateTask", json={"title": "Test Task", "priority": 2}
        );
        assert response.ok;
        assert "result" in response.data or "reports" in response.data;
        client.close();
    }
}

# --- TestResponse tests ---
test "response ok for 2xx" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/");
        assert response.ok;
        assert response.status_code == 200;
        client.close();
    }
}

test "response not ok for 4xx" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/nonexistent-endpoint");
        assert not response.ok;
        client.close();
    }
}

test "response json parsing" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/");
        json_data = response.json();
        assert isinstance(json_data, dict);
        assert "data" in json_data or "endpoints" in json_data;
        client.close();
    }
}

test "response data unwraps envelope" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.get("/");
        assert response.data is not None;
        assert "endpoints" in response.data;
        client.close();
    }
}
