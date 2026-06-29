import io;
import json;
import re;
import from http.server { BaseHTTPRequestHandler }
import from pathlib { Path }
import from urllib.parse { urlencode, urlparse }

import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { JacConfig }
import from jaclang.runtimelib.server { JacAPIServer }

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

    mach = Jac.create_j_context(
        user_root=None, base_path_dir=self._base_path, full_target_path=self._jac_file
    );
    Jac.set_context(mach);

    import from jaclang.project.config { set_config, get_config }
    pinned = self._config;
    if pinned is not None {
        set_config(pinned);
    } else {
        get_config(start_path=Path(self._base_path), force_discover=True);
    }

    Jac.jac_import(target=mod, base_path=base, lng="jac");

    self._server = JacAPIServer(module_name=mod, port=0, base_path=self._base_path);

    self._server.load_module();

    self._handler_class = self._server.create_handler();
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
    self._current_user = None;
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
            self._current_user = username;
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
            self._current_user = username;
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
    import from http.client { HTTPMessage }
    import from email.parser { Parser }

    wfile = io.BytesIO();

    header_lines = [];
    if headers {
        for (name, value) in headers.items() {
            header_lines.append(f"{name}: {value}");
        }
    }
    headers_str = "\r\n".join(header_lines);

    if headers_str {
        parsed_headers = Parser().parsestr(headers_str);
    } else {
        parsed_headers = Parser().parsestr("");
    }

    server_ref = self._server;
    handler_class = self._handler_class;
    class MockHandler(handler_class) {
        def init(mock_self: MockHandler) {
            mock_self.rfile = io.BytesIO(body or b"");
            mock_self.wfile = wfile;
            mock_self.client_address = ("127.0.0.1", 0);
            mock_self.server = type(
                "MockServer", (), {"server_address": ("localhost", 0)}
            )();
            mock_self.request_version = "HTTP/1.1";
            mock_self.command = method;
            mock_self.path = path;
            mock_self.headers = parsed_headers;
            mock_self.requestline = f"{method} {path} HTTP/1.1";
        }

        def log_message(mock_self: MockHandler, format: str, *args: any) {
            ;
        }
    }
    handler = MockHandler();

    if method == "GET" {
        handler.do_GET();
    } elif method == "POST" {
        handler.do_POST();
    } elif method == "PUT" {
        handler.do_PUT();
    } elif method == "OPTIONS" {
        handler.do_OPTIONS();
    } else {
        raise ValueError(f"Unsupported method: {method}");
    }

    return self._parse_response(wfile.getvalue());
}

impl JacTestClient._parse_response(raw_response: bytes) -> TestResponse {
    response_str = raw_response.decode("utf-8", errors="replace");

    parts = response_str.split("\r\n\r\n", 1);
    header_section = parts[0];
    body = parts[1] if len(parts) > 1 else "";

    lines = header_section.split("\r\n");
    status_line = lines[0] if lines else "HTTP/1.1 500 Internal Server Error";
    status_match = re.match(r"HTTP/\d\.\d (\d+)", status_line);
    status_code = int(status_match.group(1)) if status_match else 500;

    headers: dict[(str, str)] = {};
    for line in lines[1:] {
        if ": " in line {
            (name, value) = line.split(": ", 1);
            headers[name] = value;
        }
    }
    return TestResponse(status_code=status_code, headers=headers, text=body);
}

impl JacTestClient.server.getter -> JacAPIServer {
    self._ensure_initialized();
    return self._server;
}

impl JacTestClient.user_manager.getter -> any {
    self._ensure_initialized();
    return self._server.user_manager;
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
        import from jaclang.runtimelib.hmr { HotReloader }

        class MockWatcher {
            has additional_patterns: list[str] = [];

            def add_callback(cb: any) { }
            def start { }
            def stop { }
        }
        mock_watcher = MockWatcher();
        self._hot_reloader = HotReloader(
            base_path=base, module_name=mod, watcher=mock_watcher
        );
    }
    self._hot_reloader._process_change(self._jac_file);

    new_module = Jac.loaded_modules.get(mod);
    if new_module {
        self._server.introspector._module = new_module;
        self._server.introspector._functions = self._server.introspector._collect_functions();
        self._server.introspector._walkers = self._server.introspector._collect_walkers();
    }

    self._handler_class = self._server.create_handler();
}

impl JacTestClient.close -> None {
    import from contextlib { suppress }
    if self._server {
        with suppress(Exception) {
            self._server.user_manager.close();
        }

        if self._server.server {
            with suppress(Exception) {
                self._server.server.server_close();
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
    self._handler_class = None;
    self._auth_token = None;
    self._current_user = None;
    self._hot_reloader = None;
}
