"""MCP service layer — sole protocol boundary for all MCP communication."""

import from requests { post }
import from requests.models { Response }
import from requests.exceptions { RequestException }
import from typing { cast }
import from json { loads }

# Mutable state
obj _State {
    has server_url: str = "http://127.0.0.1:3001/mcp/",
        session_id: str | None = None,
        rpc_id: int = 0;
}

glob _st: _State = _State();

def:pub set_server_url(url: str) {
    _st.server_url = url;
    _st.session_id = None;  # Reset session on URL change
}

def:pub ping_endpoint(url: str) -> dict {
    try {
        post(
            url,
            json={"jsonrpc": "2.0", "method": "ping", "id": 0},
            headers={"Content-Type": "application/json"},
            timeout=5.0
        );
        return {"ok": True};
    } except RequestException as e {
        return {"ok": False, "message": str(e)};
    }
}

def _next_id -> int {
    _st.rpc_id += 1;
    return _st.rpc_id;
}

# Low-level HTTP
def _post_json(payload: dict, session_id: str | None = None) -> dict {
    headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json"
    };
    if session_id {
        headers["Mcp-Session-Id"] = session_id;
    }
    try {
        resp = cast(
            Response, post(_st.server_url, json=payload, headers=headers, timeout=30.0)
        );
        body: dict = {};
        try {
            body = cast(dict, resp.json());
        } except ValueError { }
        return {
            "status": resp.status_code,
            "headers": dict(resp.headers),
            "body": body
        };
    } except RequestException as e {
        raise RuntimeError("HTTP request failed: " + str(e));
    }
}

# Session management
def _initialize_mcp_session -> str {
    if _st.session_id {
        return _st.session_id;
    }
    payload = {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "jac-mcp-studio", "version": "1.0.0"}
        },
        "id": _next_id()
    };
    r = _post_json(payload);
    if r["status"] != 200 {
        raise RuntimeError("MCP initialize failed with status " + str(r["status"]));
    }
    session_id = cast(str, cast(dict, r["headers"]).get("mcp-session-id", ""));
    # Send initialized notification — no response expected
    _post_json({"jsonrpc": "2.0", "method": "notifications/initialized"}, session_id);
    _st.session_id = session_id;
    return session_id;
}

# Result extraction
def _extract_tool_result(body: dict) -> dict {
    if "error" in body {
        err = body["error"];
        msg = err.get("message", "Unknown MCP error")
            if isinstance(err, dict)
            else str(err);
        return {"ok": False, "error": msg};
    }
    try {
        text = cast(str, body["result"]["content"][0]["text"]);
        return {"ok": True, "data": loads(text)};
    } except (KeyError, IndexError, TypeError) as e {
        return {"ok": False, "error": "Failed to parse tool result: " + str(e)};
    }
}

# Core dispatcher
def _call_mcp_tool_once(tool_name: str, args: dict, session_id: str) -> dict {
    payload = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {"name": tool_name, "arguments": args},
        "id": _next_id()
    };
    r = _post_json(payload, session_id);
    parsed = _extract_tool_result(cast(dict, r["body"]));
    return {** parsed, "status": r["status"]};
}

def:pub call_mcp_tool(tool_name: str, args: dict) -> dict {
    try {
        session_id = _initialize_mcp_session();
        result = _call_mcp_tool_once(tool_name, args, session_id);
        if result.get("status") == 401 {
            _st.session_id = None;
            session_id = _initialize_mcp_session();
            result = _call_mcp_tool_once(tool_name, args, session_id);
        }
        return {
            "ok": result.get("ok", False),
            "tool": tool_name,
            "data": result.get("data", {}),
            "error": {}
                if result.get("ok")
                else {"message": result.get("error", "Unknown error")}
        };
    } except RuntimeError as e {
        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": {"message": str(e)}
        };
    }
}

# Per-tool service functions
def:pub validate_jac_service(code: str) -> dict {
    return call_mcp_tool("validate_jac", {"code": code});
}

def:pub check_syntax_service(code: str) -> dict {
    return call_mcp_tool("check_syntax", {"code": code});
}

def:pub format_jac_service(code: str) -> dict {
    return call_mcp_tool("format_jac", {"code": code});
}

def:pub py_to_jac_service(code: str) -> dict {
    return call_mcp_tool("py_to_jac", {"python_code": code});
}

def:pub get_ast_service(code: str, fmt: str = "tree") -> dict {
    return call_mcp_tool("get_ast", {"code": code, "format": fmt});
}

def:pub explain_error_service(error_message: str) -> dict {
    return call_mcp_tool("explain_error", {"error_message": error_message});
}

def:pub list_examples_service -> dict {
    return call_mcp_tool("list_examples", {});
}

def:pub get_example_service(name: str) -> dict {
    return call_mcp_tool("get_example", {"name": name});
}

def:pub search_docs_service(query: str) -> dict {
    return call_mcp_tool("search_docs", {"query": query});
}
