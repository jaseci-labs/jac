"""Tests for backend/service.jac — no MCP server required."""

import from backend.service { ping_endpoint }

# ping_endpoint
test "ping_endpoint returns ok false for unreachable URL" {
    r = ping_endpoint("http://127.0.0.1:19999/mcp/");
    assert not r["ok"] , "Expected ok: false for unreachable URL";
    assert "message" in r , "Expected a message key in the error response";
    assert r["message"] != "" , "Expected a non-empty error message";
}
