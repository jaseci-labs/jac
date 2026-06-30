import json;
import logging;
import from http.server { BaseHTTPRequestHandler, ThreadingHTTPServer }

glob LATEST_PROTOCOL_VERSION: str = "2025-06-18",
     SUPPORTED_PROTOCOL_VERSIONS: list[str] = [
         "2025-06-18",
         "2025-03-26",
         "2024-11-05"
     ],
     MCP_SERVER_VERSION: str = "0.1.0";

glob _logger = logging.getLogger("jac.mcp");

glob _BODY_ERROR: object = object();

class McpMethodNotFound(Exception) {}

class McpInvalidParams(Exception) {}

impl McpEngine.handle_message(msg: dict) -> dict | None {
    if not isinstance(msg, dict) {
        return _error_response(None, -32600, "Invalid Request");
    }
    method = msg.get("method");
    has_id = "id" in msg;
    msg_id = msg.get("id");
    params = msg.get("params");
    if not isinstance(params, dict) {
        params = {};
    }
    if method is None {
        return _error_response(msg_id, -32600, "Invalid Request") if has_id else None;
    }
    try {
        result = self._dispatch(str(method), params);
    } except McpMethodNotFound {
        return _error_response(msg_id, -32601, f"Method not found: {method}")
            if has_id
            else None;
    } except McpInvalidParams as e {
        return _error_response(msg_id, -32602, str(e)) if has_id else None;
    } except Exception as e {
        return _error_response(msg_id, -32603, f"Internal error: {e}")
            if has_id
            else None;
    }
    if not has_id {
        return None;
    }
    return {"jsonrpc": "2.0", "id": msg_id, "result": result};
}

impl McpEngine._dispatch(method: str, params: dict) -> dict {
    if method == "initialize" {
        return self._initialize(params);
    } elif method == "ping" {
        return {};
    } elif method in ["notifications/initialized", "notifications/cancelled"] {
        return {};
    } elif method == "resources/list" {
        return self._list_resources();
    } elif method == "resources/read" {
        return self._read_resource(params);
    } elif method == "tools/list" {
        return self._list_tools();
    } elif method == "tools/call" {
        return self._call_tool(params);
    } elif method == "prompts/list" {
        return self._list_prompts();
    } elif method == "prompts/get" {
        return self._get_prompt(params);
    }
    raise McpMethodNotFound(method);
}

impl McpEngine._initialize(params: dict) -> dict {
    requested = params.get("protocolVersion");
    version = requested
        if requested in SUPPORTED_PROTOCOL_VERSIONS
        else LATEST_PROTOCOL_VERSION;
    return {
        "protocolVersion": version,
        "capabilities": {"resources": {}, "tools": {}, "prompts": {}},
        "serverInfo": {"name": "jac-mcp", "version": MCP_SERVER_VERSION},
        "instructions": self.instructions
    };
}

impl McpEngine._list_resources -> dict {
    out: list = [];
    for item in self.resources.list_resources() {
        out.append(
            {
                "uri": item["uri"],
                "name": item["name"],
                "description": item.get("description", ""),
                "mimeType": item.get("mimeType", "text/plain")
            }
        );
    }
    return {"resources": out};
}

impl McpEngine._read_resource(params: dict) -> dict {
    uri = params.get("uri");
    if not uri {
        raise McpInvalidParams("missing required param 'uri'");
    }
    content = self.resources.read_resource(str(uri));
    return {"contents": [{"uri": uri, "mimeType": "text/plain", "text": content}]};
}

impl McpEngine._list_tools -> dict {
    out: list = [];
    for item in self.tools.list_tools() {
        out.append(
            {
                "name": item["name"],
                "description": item["description"],
                "inputSchema": item.get(
                    "inputSchema", {"type": "object", "properties": {}}
                )
            }
        );
    }
    return {"tools": out};
}

impl McpEngine._call_tool(params: dict) -> dict {
    name = params.get("name");
    if not name {
        raise McpInvalidParams("missing required param 'name'");
    }
    arguments = params.get("arguments");
    if not isinstance(arguments, dict) {
        arguments = {};
    }
    result = self.tools.call_tool(str(name), arguments);
    return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]};
}

impl McpEngine._list_prompts -> dict {
    out: list = [];
    for item in self.prompts.list_prompts() {
        pargs: list = [];
        for arg in item.get("arguments", []) {
            pargs.append(
                {
                    "name": arg["name"],
                    "description": arg.get("description", ""),
                    "required": arg.get("required", False)
                }
            );
        }
        out.append(
            {
                "name": item["name"],
                "description": item["description"],
                "arguments": pargs
            }
        );
    }
    return {"prompts": out};
}

impl McpEngine._get_prompt(params: dict) -> dict {
    name = params.get("name");
    if not name {
        raise McpInvalidParams("missing required param 'name'");
    }
    arguments = params.get("arguments");
    if not isinstance(arguments, dict) {
        arguments = {};
    }
    result = self.prompts.get_prompt(str(name), arguments);
    messages: list = [];
    for msg in result.get("messages", []) {
        messages.append(
            {"role": msg["role"], "content": {"type": "text", "text": msg["content"]}}
        );
    }
    return {"description": result.get("description", ""), "messages": messages};
}

impl build_engine(instructions: str = "") -> McpEngine {
    import from jaclang.cli.mcp.resources { ResourceProvider }
    import from jaclang.cli.mcp.tools { ToolProvider }
    import from jaclang.cli.mcp.prompts { PromptProvider }

    rp = ResourceProvider();
    rp.index_resources();
    return McpEngine(
        resources=rp,
        tools=ToolProvider(),
        prompts=PromptProvider(),
        instructions=instructions
    );
}

impl serve_stdio(engine: McpEngine) -> None {
    import sys;
    stdin = sys.stdin.buffer;
    stdout = sys.stdout.buffer;
    while True {
        line = stdin.readline();
        if not line {
            break;
        }
        text = line.strip();
        if not text {
            continue;
        }
        try {
            msg = json.loads(text);
        } except Exception {
            _stdio_write(
                stdout,
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Parse error"}
                }
            );
            continue;
        }
        reply = _process(engine, msg);
        if reply is not None {
            _stdio_write(stdout, reply);
        }
    }
}

impl serve_streamable_http(engine: McpEngine, host: str, port: int) -> None {
    httpd = _make_http_server(host, port, _StreamableHttpHandler);
    httpd.engine = engine;
    httpd.mcp_path = "/mcp";
    httpd.session_id = _new_session_id();
    _logger.info(f"jac-mcp streamable-http listening on http://{host}:{port}/mcp");
    _serve_forever(httpd);
}

impl serve_sse(engine: McpEngine, host: str, port: int) -> None {
    import threading;
    httpd = _make_http_server(host, port, _SseHandler);
    httpd.engine = engine;
    httpd.sessions = {};
    httpd.lock = threading.Lock();
    _logger.info(f"jac-mcp sse listening on http://{host}:{port}/sse");
    _serve_forever(httpd);
}

def _error_response(msg_id: any, code: int, message: str) -> dict {
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "error": {"code": code, "message": message}
    };
}

def _process(engine: McpEngine, msg: any) -> any {
    if isinstance(msg, list) {
        responses: list = [];
        for m in msg {
            r = engine.handle_message(m);
            if r is not None {
                responses.append(r);
            }
        }

        if not responses {
            return None;
        }
        return responses;
    }
    return engine.handle_message(msg);
}

def _stdio_write(stream: any, payload: any) {
    stream.write((json.dumps(payload) + "\n").encode("utf-8"));
    stream.flush();
}

def _new_session_id -> str {
    import uuid;
    return uuid.uuid4().hex;
}

def _query_param(path: str, key: str) -> str | None {
    import from urllib.parse { urlparse, parse_qs }
    vals = parse_qs(urlparse(path).query).get(key);
    return vals[0] if vals else None;
}

def _make_http_server(host: str, port: int, handler: object) -> object {
    httpd = ThreadingHTTPServer((host, port), handler);
    httpd.daemon_threads = True;
    return httpd;
}

def _serve_forever(httpd: object) {
    try {
        httpd.serve_forever();
    } except KeyboardInterrupt { } finally {
        httpd.server_close();
    }
}

class _StreamableHttpHandler(BaseHTTPRequestHandler) {
    def do_POST(self: _StreamableHttpHandler) -> None {
        if self.path.split("?")[0] != self.server.mcp_path {
            self._send_status(404);
            return;
        }
        msg = self._read_body();
        if msg is _BODY_ERROR {
            self._send_json(
                400,
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Parse error"}
                }
            );
            return;
        }
        if msg is None {
            self._send_status(202);
            return;
        }
        reply = _process(self.server.engine, msg);
        if reply is None {
            self._send_status(202);
        } else {
            self._send_json(200, reply);
        }
    }

    def do_GET(self: _StreamableHttpHandler) {
        self._send_status(405);
    }

    def do_DELETE(self: _StreamableHttpHandler) {
        self._send_status(200);
    }

    def _read_body(self: _StreamableHttpHandler) -> any {
        length = int(self.headers.get("Content-Length", 0) or 0);
        if length <= 0 {
            return None;
        }
        raw = self.rfile.read(length);
        if not raw {
            return None;
        }
        try {
            return json.loads(raw.decode("utf-8"));
        } except Exception {
            return _BODY_ERROR;
        }
    }

    def _send_json(self: _StreamableHttpHandler, status: int, payload: any) {
        data = json.dumps(payload).encode("utf-8");
        self.send_response(status);
        self.send_header("Content-Type", "application/json");
        self.send_header("Content-Length", str(len(data)));
        self.send_header("Mcp-Session-Id", self.server.session_id);
        self.end_headers();
        self.wfile.write(data);
    }

    def _send_status(self: _StreamableHttpHandler, status: int) {
        self.send_response(status);
        self.send_header("Content-Length", "0");
        self.send_header("Mcp-Session-Id", self.server.session_id);
        self.end_headers();
    }

    def log_message(self: _StreamableHttpHandler, fmt: str, *args: any) {
        _logger.debug("streamable-http %s", fmt % args);
    }
}

class _SseHandler(BaseHTTPRequestHandler) {
    def do_GET(self: _SseHandler) -> None {
        import queue;
        if self.path.split("?")[0] != "/sse" {
            self._send_status(404);
            return;
        }
        session_id = _new_session_id();
        q = queue.Queue();
        with self.server.lock {
            self.server.sessions[session_id] = q;
        }
        self.send_response(200);
        self.send_header("Content-Type", "text/event-stream");
        self.send_header("Cache-Control", "no-cache");
        self.send_header("Connection", "keep-alive");
        self.end_headers();
        try {
            self._send_event("endpoint", f"/messages?session_id={session_id}");
            while True {
                try {
                    item = q.get(timeout=15.0);
                } except Exception {
                    self.wfile.write(b": keep-alive\n\n");
                    self.wfile.flush();
                    continue;
                }
                if item is None {
                    break;
                }
                self._send_event("message", item);
            }
        } except Exception { } finally {
            with self.server.lock {
                self.server.sessions.pop(session_id, None);
            }
        }
    }

    def do_POST(self: _SseHandler) -> None {
        if self.path.split("?")[0] != "/messages" {
            self._send_status(404);
            return;
        }
        session_id = _query_param(self.path, "session_id");
        with self.server.lock {
            q = self.server.sessions.get(session_id);
        }
        if q is None {
            self._send_status(404);
            return;
        }
        length = int(self.headers.get("Content-Length", 0) or 0);
        raw = self.rfile.read(length) if length > 0 else b"";
        try {
            msg = json.loads(raw.decode("utf-8")) if raw else None;
        } except Exception {
            self._send_status(400);
            return;
        }
        self._send_status(202);
        if msg is None {
            return;
        }
        reply = _process(self.server.engine, msg);
        if reply is not None {
            q.put(json.dumps(reply));
        }
    }

    def _send_event(self: _SseHandler, event: str, data: str) {
        self.wfile.write(f"event: {event}\ndata: {data}\n\n".encode("utf-8"));
        self.wfile.flush();
    }

    def _send_status(self: _SseHandler, status: int) {
        self.send_response(status);
        self.send_header("Content-Length", "0");
        self.end_headers();
    }

    def log_message(self: _SseHandler, fmt: str, *args: any) {
        _logger.debug("sse %s", fmt % args);
    }
}
