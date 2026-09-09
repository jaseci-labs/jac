import io;
import json;
import re;
import from pathlib { Path }
import from urllib.parse { urlencode }

import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { JacConfig }
import from jaclang.server.server { JacAPIServer }

impl TestResponse.json -> dict[str, any] {
    if self._json_cache is None {
        try {
            self._json_cache = json.loads(self.text);
        } except json.JSONDecodeError {
            self._json_cache = {};
        }
    }
    return self._json_cache;
}

impl TestResponse.ok.getter -> bool {
    return 200 <= self.status_code < 300;
}

impl TestResponse.data.getter -> (dict[str, any] | None) {
    response_json = self.json();
    if not isinstance(response_json, dict) {
        return response_json;
    }
    if response_json.get("ok") is False
        and isinstance(response_json.get("error"), dict) {
        detail = response_json["error"];
        unwrapped: dict[str, any] = {
            "error": str(detail.get("message") or "Request failed")
        };
        if detail.get("code") {
            unwrapped["error_code"] = detail["code"];
        }
        if detail.get("details") is not None {
            unwrapped["details"] = detail["details"];
        }
        return unwrapped;
    }
    if "data" in response_json {
        return response_json["data"];
    }
    return response_json;
}

impl JacTestClient.from_file(
    jac_file: str,
    base_path: (str | None) = None,
    module_name: (str | None) = None,
    config: (JacConfig | None) = None
) -> JacTestClient {
    resolved_path = Path(jac_file).resolve();
    if not resolved_path.exists() {
        raise FileNotFoundError(f"Jac file not found: {jac_file}");
    }
    effective_base_path = base_path or str(resolved_path.parent);
    return JacTestClient(
        _jac_file=str(resolved_path), _base_path=effective_base_path, _config=config
    );
}

impl JacTestClient._ensure_initialized -> None {
    import os;
    if self._server is not None {
        return;
    }

    (base, mod) = os.path.split(self._jac_file);
    base = base or "./";
    if self._jac_file.endswith(".jac") {
        mod = mod[:-4];
    }

    Jac.set_base_path(self._base_path);
    Jac.set_full_target_path(self._jac_file);

    mach = Jac.create_j_context(
        user_root=None, base_path_dir=self._base_path, full_target_path=self._jac_file
    );
    Jac.set_context(mach);

    import from jaclang.project.config { set_config, get_config }
    import from jaclang.compiler.frontend.codeinfo { set_effective_default_codespace }
    pinned = self._config;
    if pinned is not None {
        set_config(pinned);
    } else {
        get_config(start_path=Path(self._base_path), force_discover=True);
    }

    set_effective_default_codespace('server');

    Jac.jac_import(target=mod, base_path=base, lng="jac");

    self._server = JacAPIServer(
        module_name=mod, port=0, base_path=self._base_path, module_file=self._jac_file
    );

    self._server.load_module();

    server_ref: any = self._server;
    server_ref._ensure_internal_users();
    self._app = server_ref.build_app();
}

impl JacTestClient.get(
    path: str,
    params: (dict[str, any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("GET", path, params=params, headers=headers);
}

impl JacTestClient.post(
    path: str,
    json: (dict[str, any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("POST", path, json=json, headers=headers);
}

impl JacTestClient.put(
    path: str,
    json: (dict[str, any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("PUT", path, json=json, headers=headers);
}

impl JacTestClient.request(
    method: str,
    path: str,
    json: (dict[str, any] | None) = None,
    params: (dict[str, any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    import json as json_mod;
    self._ensure_initialized();

    if params {
        path = f"{path}?{urlencode(params)}";
    }

    body: (bytes | None) = None;
    if json is not None {
        body = json_mod.dumps(json).encode("utf-8");
    }

    request_headers = dict(headers) if headers else {};
    if body {
        request_headers.setdefault("Content-Type", "application/json");
        request_headers.setdefault("Content-Length", str(len(body)));
    }

    if self._auth_token and "Authorization" not in request_headers {
        request_headers["Authorization"] = f"Bearer {self._auth_token}";
    }
    return self._execute_request(method, path, body, request_headers);
}

impl JacTestClient.set_auth_token(token: str) -> None {
    self._auth_token = token;
}

impl JacTestClient.clear_auth -> None {
    self._auth_token = None;
}

impl JacTestClient.register_user(username: str, password: str) -> TestResponse {
    response = self.post(
        "/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        }
    );
    if response.ok {
        data = response.data;
        if data and "token" in data {
            self._auth_token = data["token"];
        }
    }
    return response;
}

impl JacTestClient.login(username: str, password: str) -> TestResponse {
    response = self.post(
        "/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        }
    );
    if response.ok {
        data = response.data;
        if data and "token" in data {
            self._auth_token = data["token"];
        }
    }
    return response;
}

impl JacTestClient._execute_request(
    method: str,
    path: str,
    body: (bytes | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    if method not in ("GET", "POST", "PUT", "OPTIONS") {
        raise ValueError(f"Unsupported method: {method}");
    }
    header_obj = Headers();
    if headers {
        for (name, value) in headers.items() {
            header_obj.append(str(name), str(value));
        }
    }
    split_path = path.split('?', 1);
    query = split_path[1] if len(split_path) > 1 else '';
    request = Request(
        method=method,
        url=URL(path=split_path[0], query=query),
        headers=header_obj,
        query_params=QueryParams(raw=parse_query_string(query)),
        body=body or b"",
        client_host="127.0.0.1"
    );
    outcome: tuple[Response, bytes] = run_blocking(
        dispatch_and_collect(self._app, request)
    );
    response = outcome[0];
    content = outcome[1];
    response_headers: dict[(str, str)] = {};
    for (name, value) in response.headers.items() {
        response_headers[name] = value;
    }
    if "Content-Type" not in response_headers {
        response_headers["Content-Type"] = response.content_type_header();
    }
    return TestResponse(
        status_code=response.status_code,
        headers=response_headers,
        text=content.decode("utf-8", errors="replace")
    );
}

impl JacTestClient.server.getter -> JacAPIServer {
    self._ensure_initialized();
    server = self._server;
    if server is None {
        raise RuntimeError("JacTestClient failed to start its server");
    }
    return server;
}

impl JacTestClient.user_manager.getter -> any {
    return self.server.user_manager;
}

impl JacTestClient.reload -> None {
    import from pathlib { Path }
    import os;
    self._ensure_initialized();

    (base, mod) = os.path.split(self._jac_file);
    base = base or "./";
    if self._jac_file.endswith(".jac") {
        mod = mod[:-4];
    }

    if self._hot_reloader is None {
        import from jaclang.server.hmr { HotReloader }

        class MockWatcher {
            has additional_patterns: list[str] = [];

            def add_callback(cb: any) {}
            def start {}
            def stop {}
        }
        mock_watcher = MockWatcher();
        self._hot_reloader = HotReloader(
            base_path=base, module_name=mod, watcher=mock_watcher
        );
    }
    self._hot_reloader._process_change(self._jac_file);

    new_module = Jac.loaded_modules.get(mod);
    if new_module {
        introspector = self.server.introspector;
        introspector._module = new_module;
        introspector._functions = introspector._collect_functions();
        introspector._walkers = introspector._collect_walkers();
    }

    server_ref: any = self._server;
    self._app = server_ref.build_app();
}

impl JacTestClient.close -> None {
    import from contextlib { suppress }
    if self._server {
        with suppress(Exception) {
            self._server.user_manager.close();
        }

        if self._server.server {
            with suppress(Exception) {
                self._server.server.request_stop();
            }
        }
    }

    with suppress(Exception) {
        ctx = Jac.get_context();
        if ctx {
            Jac.commit();
            ctx.close();
        }
    }
    self._server = None;
    self._app = None;
    self._auth_token = None;
    self._hot_reloader = None;
}
