"""Implementation of test client components."""

import io;
import json;
import re;
import from http.server { BaseHTTPRequestHandler }
import from pathlib { Path }
import from typing { Any }
import from urllib.parse { urlencode, urlparse }

import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.server { JacAPIServer }

"""Parse response body as JSON."""
impl TestResponse.json -> dict[str, Any] {
    if self._json_cache is None {
        try {
            self._json_cache = json.loads(self.text);
        } except json.JSONDecodeError {
            self._json_cache = {};
        }
    }
    return self._json_cache;
}

"""Check if response indicates success."""
impl TestResponse.ok -> bool {
    return 200 <= self.status_code < 300;
}

"""Get data from response, handling TransportResponse envelope."""
impl TestResponse.data -> (dict[str, Any] | None) {
    response_json = self.json();
    # Handle TransportResponse envelope format
    if "data" in response_json {
        return response_json["data"];
    }
    return response_json;
}

"""Create test client from a .jac file path."""
impl JacTestClient.from_file(
    jac_file: str, base_path: (str | None) = None, module_name: (str | None) = None
) -> JacTestClient {
    resolved_path = Path(jac_file).resolve();
    if not resolved_path.exists() {
        raise FileNotFoundError(f"Jac file not found: {jac_file}") ;
    }
    effective_base_path = base_path or str(resolved_path.parent);
    return JacTestClient(_jac_file=str(resolved_path), _base_path=effective_base_path);
}

"""Initialize server and handler lazily."""
impl JacTestClient._ensure_initialized -> None {
    import os;
    if self._server is not None {
        return;
    }
    # Get module name from file
    (base, mod) = os.path.split(self._jac_file);
    base = base or "./";
    if self._jac_file.endswith(".jac") {
        mod = mod[:-4];
    }
    # Set base path for isolated storage
    Jac.set_base_path(self._base_path);
    # Create execution context
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    # Load the Jac module
    Jac.jac_import(target=mod, base_path=base, override_name="__main__", lng="jac");
    # Create server in test mode (port=0 means no real socket binding)
    self._server = JacAPIServer(
        module_name="__main__", port=0, base_path=self._base_path
    );
    # Load module metadata
    self._server.load_module();
    # Get handler class for request processing
    self._handler_class = self._server.create_handler();
}

"""Make a GET request."""
impl JacTestClient.get(
    path: str,
    params: (dict[str, Any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("GET", path, params=params, headers=headers);
}

"""Make a POST request with JSON body."""
impl JacTestClient.post(
    path: str,
    json: (dict[str, Any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("POST", path, json=json, headers=headers);
}

"""Make a PUT request with JSON body."""
impl JacTestClient.put(
    path: str,
    json: (dict[str, Any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    return self.request("PUT", path, json=json, headers=headers);
}

"""Make a request with specified method."""
impl JacTestClient.request(
    method: str,
    path: str,
    json: (dict[str, Any] | None) = None,
    params: (dict[str, Any] | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    import json as json_mod;
    self._ensure_initialized();
    # Build path with query params
    if params {
        path = f"{path}?{urlencode(params)}";
    }
    # Build body
    body: (bytes | None) = None;
    if json is not None {
        body = json_mod.dumps(json).encode("utf-8");
    }
    # Build headers
    request_headers = dict(headers) if headers else {};
    if body {
        request_headers.setdefault("Content-Type", "application/json");
        request_headers.setdefault("Content-Length", str(len(body)));
    }
    # Add auth token if set
    if self._auth_token and "Authorization" not in request_headers {
        request_headers["Authorization"] = f"Bearer {self._auth_token}";
    }
    return self._execute_request(method, path, body, request_headers);
}

"""Set authentication token."""
impl JacTestClient.set_auth_token(token: str) -> None {
    self._auth_token = token;
}

"""Clear authentication."""
impl JacTestClient.clear_auth -> None {
    self._auth_token = None;
    self._current_user = None;
}

"""Register a new user and set auth token."""
impl JacTestClient.register_user(username: str, password: str) -> TestResponse {
    response = self.post(
        "/user/register", json={"username": username, "password": password}
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

"""Login existing user and set auth token."""
impl JacTestClient.login(username: str, password: str) -> TestResponse {
    response = self.post(
        "/user/login", json={"username": username, "password": password}
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

"""Execute request through mock handler."""
impl JacTestClient._execute_request(
    method: str,
    path: str,
    body: (bytes | None) = None,
    headers: (dict[str, str] | None) = None
) -> TestResponse {
    import from http.client { HTTPMessage }
    import from email.parser { Parser }
    # Create mock file objects
    wfile = io.BytesIO();
    # Build request headers string for parsing
    header_lines = [];
    if headers {
        for (name, value) in headers.items() {
            header_lines.append(f"{name}: {value}");
        }
    }
    headers_str = "\r\n".join(header_lines);
    # Parse headers into HTTPMessage format
    if headers_str {
        parsed_headers = Parser().parsestr(headers_str);
    } else {
        parsed_headers = Parser().parsestr("");
    }
    # Create mock handler that doesn't try to read from socket
    server_ref = self._server;
    handler_class = self._handler_class;
    class MockHandler(handler_class) {
        def init(mock_self: MockHandler) -> None {
            # Set up mock attributes without calling parent __init__
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

        def log_message(mock_self: MockHandler, format: str, *args: Any) -> None {
            # Suppress logging during tests
            ;
        }
    }
    handler = MockHandler();
    # Execute the appropriate method
    if method == "GET" {
        handler.do_GET();
    } elif method == "POST" {
        handler.do_POST();
    } elif method == "PUT" {
        handler.do_PUT();
    } elif method == "OPTIONS" {
        handler.do_OPTIONS();
    } else {
        raise ValueError(f"Unsupported method: {method}") ;
    }
    # Parse response
    return self._parse_response(wfile.getvalue());
}

"""Parse raw HTTP response bytes into TestResponse."""
impl JacTestClient._parse_response(raw_response: bytes) -> TestResponse {
    response_str = raw_response.decode("utf-8", errors="replace");
    # Split headers and body
    parts = response_str.split("\r\n\r\n", 1);
    header_section = parts[0];
    body = parts[1] if len(parts) > 1 else "";
    # Parse status line
    lines = header_section.split("\r\n");
    status_line = lines[0] if lines else "HTTP/1.1 500 Internal Server Error";
    status_match = re.match(r"HTTP/\d\.\d (\d+)", status_line);
    status_code = int(status_match.group(1)) if status_match else 500;
    # Parse headers
    headers: dict[(str, str)] = {};
    for line in lines[1:] {
        if ": " in line {
            (name, value) = line.split(": ", 1);
            headers[name] = value;
        }
    }
    return TestResponse(status_code=status_code, headers=headers, text=body);
}

"""Get the underlying server instance."""
impl JacTestClient.server -> JacAPIServer {
    self._ensure_initialized();
    return self._server;
}

"""Get the user manager."""
impl JacTestClient.user_manager -> Any {
    self._ensure_initialized();
    return self._server.user_manager;
}

"""Reload the module (for HMR testing)."""
impl JacTestClient.reload -> None {
    import os;
    import sys;
    self._ensure_initialized();
    # Get module name from file
    (base, mod) = os.path.split(self._jac_file);
    base = base or "./";
    if self._jac_file.endswith(".jac") {
        mod = mod[:-4];
    }
    # Clear cached module to force reload (same as HotReloader)
    if "__main__" in sys.modules {
        del sys.modules["__main__"] ;
    }
    # Also clear the module from Jac.loaded_modules
    if "__main__" in Jac.loaded_modules {
        del Jac.loaded_modules["__main__"] ;
    }
    # Also clear from mod.hub to force recompilation
    try {
        resolved_path = str(Path(self._jac_file).resolve());
        if resolved_path in Jac.program.mod.hub {
            del Jac.program.mod.hub[resolved_path] ;
        }
        if self._jac_file in Jac.program.mod.hub {
            del Jac.program.mod.hub[self._jac_file] ;
        }
    } except Exception {
        ;  # Ignore if hub doesn't exist
    }
    # Re-import the module with reload flag
    Jac.jac_import(
        target=mod,
        base_path=base,
        override_name="__main__",
        lng="jac",
        reload_module=True
    );
    # Update introspector's cached module reference directly
    new_module = Jac.loaded_modules.get("__main__");
    self._server.introspector._module = new_module;
    self._server.introspector._functions = self._server.introspector._collect_functions();
    self._server.introspector._walkers = self._server.introspector._collect_walkers();
    # Recreate handler class with new module
    self._handler_class = self._server.create_handler();
}

"""Cleanup resources."""
impl JacTestClient.close -> None {
    import from contextlib { suppress }
    if self._server {
        with suppress(Exception) {
            self._server.user_manager.close();
        }
        # Close the mock server socket if it was created
        if self._server.server {
            with suppress(Exception) {
                self._server.server.server_close();
            }
        }
    }
    # Close execution context
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
}
