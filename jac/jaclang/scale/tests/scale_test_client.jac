import shutil;
import glob;
import tempfile;
import contextlib;
import from pathlib { Path }

def make_client(fixture_file: str = "test_api.jac") -> ScaleTestClient {
    fixtures_dir = Path(__file__).parent / "fixtures";
    tmp = tempfile.mkdtemp();

    for f in glob.glob(str(fixtures_dir / "*")) {
        if Path(f).is_file() {
            shutil.copy2(f, Path(tmp) / Path(f).name);
        }
    }
    client = ScaleTestClient.from_file(str(fixtures_dir / fixture_file), base_path=tmp);
    client._tmp_dir = tmp;
    return client;
}

def extract_data(json_response: dict[str, any]) -> dict[str, any] {
    if isinstance(json_response, dict) and "ok" in json_response {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            result: dict[str, any] = {
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

obj ScaleTestClient {
    has _jac_file: str,
        _base_path: str,
        _server: any | None = None,
        _client: any | None = None,
        _runtime: any | None = None,
        _tmp_dir: str | None = None;

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

    def _initialize {
        import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }

        self._runtime = prepare_inprocess_runtime(
            self._jac_file,
            self._base_path,
            endpoint_profile="test",
            setup_background_services=False,
            transport_kind="testclient"
        );
        self._server = self._runtime.server;
        self._client = self._runtime.client;
    }

    def get(
        path: str,
        headers: dict[str, str] | None = None,
        params: dict[str, any] | None = None,
        allow_redirects: bool = True
    ) -> any {
        return self._client.get(
            path, headers=headers or {}, params=params, follow_redirects=allow_redirects
        );
    }

    def post(
        path: str,
        json: dict[str, any] | None = None,
        headers: dict[str, str] | None = None,
        data: dict[str, any] | None = None,
        content: str | bytes | None = None,
        files: any | None = None
    ) -> any {
        kwargs: dict[str, any] = {"headers": headers or {}};
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

    def put(
        path: str,
        json: dict[str, any] | None = None,
        headers: dict[str, str] | None = None
    ) -> any {
        return self._client.put(path, json=json, headers=headers or {});
    }

    def delete(path: str, headers: dict[str, str] | None = None) -> any {
        return self._client.delete(path, headers=headers or {});
    }

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

        error = data.get("error", {});
        if error.get("code") == "IDENTITY_TAKEN" {
            return (username, "User already exists");
        }
        raise RuntimeError(f"User registration failed: {data}");
    }

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

    def admin_login(username: str = "admin", password: str = "changeme") -> str {
        response = self.post(
            "/admin/login", json={"username": username, "password": password}
        );
        data = response.json();
        if data.get("ok") and data.get("data") {
            login_data = data["data"];

            if login_data.get("requires_password_reset") {
                token = login_data["token"];
                new_password = "TestAdmin123!";
                self.post(
                    "/admin/reset-password",
                    json={"current_password": password, "new_password": new_password},
                    headers={"Authorization": f"Bearer {token}"}
                );

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

    has server: any {
        getter {
            return self._server;
        }
    }

    has raw_client: any {
        getter {
            return self._client;
        }
    }

    def close {
        if self._runtime {
            self._runtime.close();
            self._runtime = None;
        }
        self._client = None;
        self._server = None;
        if self._tmp_dir {
            shutil.rmtree(self._tmp_dir, ignore_errors=True);
            self._tmp_dir = None;
        }
    }
}
