"""In-process test client for jac-scale's JacAPIServer (no socket binding).

Uses Starlette's TestClient to dispatch requests through FastAPI's ASGI app
without opening OS ports. Supports admin login, authenticated requests, etc.

Example:
    client = ScaleTestClient.from_file("app.jac", base_path="/tmp/test");
    token = client.admin_login("admin", "changeme");
    response = client.get("/admin/metrics", headers={"Authorization": f"Bearer {token}"});
    assert response.status_code == 200;
    client.close();
"""

import os;
import sys;
import shutil;
import glob;
import tempfile;
import contextlib;
import from pathlib { Path }
import from typing { Any }

import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.constant { Constants as Con }

"""Create an isolated ScaleTestClient with temp dir from a fixture file."""
def make_client(fixture_file: str = "test_api.jac") -> ScaleTestClient {
    fixtures_dir = Path(__file__).parent / "fixtures";
    tmp = tempfile.mkdtemp();
    # Copy fixture files to temp dir for isolation
    for f in glob.glob(str(fixtures_dir / "*")) {
        if Path(f).is_file() {
            shutil.copy2(f, Path(tmp) / Path(f).name);
        }
    }
    client = ScaleTestClient.from_file(str(fixtures_dir / fixture_file), base_path=tmp);
    client._tmp_dir = tmp;
    return client;
}

"""Extract data from TransportResponse envelope format."""
def extract_data(json_response: dict[str, Any]) -> dict[str, Any] {
    if isinstance(json_response, dict) and "ok" in json_response {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            result: dict[str, Any] = {
                "error": error_info.get("message", "Unknown error")
            };
            if "code" in error_info {
                result["error_code"] = error_info["code"];
            }
            return result;
        }
    }
    return json_response;
}

"""Test client for jac-scale's JacAPIServer using Starlette TestClient."""
obj ScaleTestClient {
    has _jac_file: str,
        _base_path: str,
        _server: Any | None = None,
        _client: Any | None = None,
        _tmp_dir: str | None = None;

    """Create test client from a .jac file path."""
    static def from_file(
        jac_file: str, base_path: str | None = None
    ) -> ScaleTestClient {
        resolved = Path(jac_file).resolve();
        if not resolved.exists() {
            raise FileNotFoundError(f"Jac file not found: {jac_file}");
        }
        effective_base = base_path or str(resolved.parent);
        client = ScaleTestClient(_jac_file=str(resolved), _base_path=effective_base);
        client._initialize();
        return client;
    }

    """Initialize the jac-scale server and Starlette TestClient."""
    def _initialize {
        import from starlette.testclient { TestClient }
        import from jac_scale.serve { JacAPIServer }

        (base, mod) = os.path.split(self._jac_file);
        base = base or "./";
        if mod.endswith(".jac") {
            mod = mod[:-4];
        }

        Jac.set_base_path(self._base_path);
        mach = Jac.create_j_context(user_root=None);
        Jac.set_context(mach);
        # Remove any previously loaded module with same name to avoid collisions
        # (e.g., test runner may have loaded a test file with the same module name)
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.jac_import(target=mod, base_path=base, lng="jac");

        # port=0 => test mode (no socket binding; postinit creates a bare JFastApiServer)
        self._server = JacAPIServer(module_name=mod, port=0, base_path=self._base_path);
        self._server.load_module();

        # Register all endpoints (same as start() but without run_server)
        self._server.register_health_endpoint();
        self._server.register_auth_endpoints();
        self._server.register_graph_endpoint();
        self._server.register_admin_endpoints();
        self._server.register_llm_telemetry_endpoints();
        self._server.register_walkers_endpoints();
        self._server.register_functions_endpoints();
        self._server.register_webhook_endpoints();
        self._server.register_static_file_endpoint();
        self._server.register_page_endpoint();
        self._server.register_client_js_endpoint();
        self._server.user_manager.create_internal_user(
            Con.GUEST.value, '__no_password__'
        );

        # Execute endpoint registration (compiles JEndPoints into FastAPI routes)
        self._server.server.create_server();

        # Wrap the FastAPI app with Starlette TestClient
        self._client = TestClient(
            self._server.server.app, raise_server_exceptions=False
        );
    }

    """Make a GET request."""
    def get(
        path: str,
        headers: dict[str, str] | None = None,
        params: dict[str, Any] | None = None,
        allow_redirects: bool = True
    ) -> Any {
        return self._client.get(
            path, headers=headers or {}, params=params, follow_redirects=allow_redirects
        );
    }

    """Make a POST request with JSON body."""
    def post(
        path: str,
        json: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        data: dict[str, Any] | None = None,
        content: str | bytes | None = None,
        files: Any | None = None
    ) -> Any {
        kwargs: dict[str, Any] = {"headers": headers or {}};
        if json is not None {
            kwargs["json"] = json;
        }
        if data is not None {
            kwargs["data"] = data;
        }
        if content is not None {
            kwargs["content"] = content;
        }
        if files is not None {
            kwargs["files"] = files;
        }
        return self._client.post(path, **kwargs);
    }

    """Make a PUT request with JSON body."""
    def put(
        path: str,
        json: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None
    ) -> Any {
        return self._client.put(path, json=json, headers=headers or {});
    }

    """Make a DELETE request."""
    def delete(path: str, headers: dict[str, str] | None = None) -> Any {
        return self._client.delete(path, headers=headers or {});
    }

    """Register a user and return (user_id, message) tuple.
    If the user already exists, returns the username as user_id."""
    def register_user(username: str, password: str) -> tuple[str, str] {
        response = self.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": username}],
                "credential": {"type": "password", "password": password}
            }
        );
        data = response.json();
        if data.get("ok") and data.get("data") {
            return (
                data["data"].get("user_id", username),
                data["data"].get("message", "")
            );
        }
        # If user already exists, treat as success
        error = data.get("error", {});
        if error.get("code") == "IDENTITY_TAKEN" {
            return (username, "User already exists");
        }
        raise RuntimeError(f"User registration failed: {data}");
    }

    """Login a user and return the token."""
    def login_user(username: str, password: str) -> str {
        response = self.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": password}
            }
        );
        data = response.json();
        if data.get("ok") and data.get("data") and "token" in data["data"] {
            return data["data"]["token"];
        }
        raise RuntimeError(f"User login failed: {data}");
    }

    """Login as admin. Returns the auth token string."""
    def admin_login(username: str = "admin", password: str = "changeme") -> str {
        response = self.post(
            "/admin/login", json={"username": username, "password": password}
        );
        data = response.json();
        if data.get("ok") and data.get("data") {
            login_data = data["data"];
            # Handle bootstrap password reset if required
            if login_data.get("requires_password_reset") {
                token = login_data["token"];
                new_password = "TestAdmin123!";
                self.post(
                    "/admin/reset-password",
                    json={"current_password": password, "new_password": new_password},
                    headers={"Authorization": f"Bearer {token}"}
                );
                # Re-login with new password
                response = self.post(
                    "/admin/login",
                    json={"username": username, "password": new_password}
                );
                data = response.json();
                if data.get("ok") and data.get("data") {
                    return data["data"]["token"];
                }
            }
            return login_data["token"];
        }
        raise RuntimeError(f"Admin login failed: {data}");
    }

    """Get the underlying server instance."""
    @property
    def server -> Any {
        return self._server;
    }

    """Get the underlying Starlette TestClient."""
    @property
    def raw_client -> Any {
        return self._client;
    }

    """Cleanup resources."""
    def close {
        if self._client {
            self._client.close();
            self._client = None;
        }
        self._server = None;
        if self._tmp_dir {
            shutil.rmtree(self._tmp_dir, ignore_errors=True);
            self._tmp_dir = None;
        }
    }
}
