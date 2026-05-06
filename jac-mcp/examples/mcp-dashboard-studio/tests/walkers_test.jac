"""Tests for walker input guards in main.jac — no MCP server required."""

import from main {
    set_mcp_server,
    validate_jac,
    check_syntax,
    format_jac,
    py_to_jac,
    get_ast,
    explain_error,
    list_examples,
    get_example,
    search_docs
}

# validate_jac
test "validate_jac rejects empty code" {
    w = root spawn validate_jac(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "validate_jac" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "validate_jac rejects whitespace-only code" {
    w = root spawn validate_jac(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

# check_syntax
test "check_syntax rejects empty code" {
    w = root spawn check_syntax(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "check_syntax" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "check_syntax rejects whitespace-only code" {
    w = root spawn check_syntax(code="  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

# format_jac
test "format_jac rejects empty code" {
    w = root spawn format_jac(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "format_jac" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "format_jac rejects whitespace-only code" {
    w = root spawn format_jac(code="\n\n");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

# py_to_jac
test "py_to_jac rejects empty code" {
    w = root spawn py_to_jac(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "py_to_jac" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "py_to_jac rejects whitespace-only code" {
    w = root spawn py_to_jac(code="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

# get_ast
test "get_ast rejects empty code" {
    w = root spawn get_ast(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "get_ast" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "get_ast rejects whitespace-only code" {
    w = root spawn get_ast(code="  \t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

# explain_error
test "explain_error rejects empty error message" {
    w = root spawn explain_error(error_message="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty error message";
    assert result["tool"] == "explain_error" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "explain_error rejects whitespace-only error message" {
    w = root spawn explain_error(error_message="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only error message";
}

# get_example
test "get_example rejects empty name" {
    w = root spawn get_example(name="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty name";
    assert result["tool"] == "get_example" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "get_example rejects whitespace-only name" {
    w = root spawn get_example(name="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only name";
}

# search_docs
test "search_docs rejects empty query" {
    w = root spawn search_docs(query="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty query";
    assert result["tool"] == "search_docs" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "search_docs rejects whitespace-only query" {
    w = root spawn search_docs(query="\n");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only query";
}

# Graceful failure — no MCP server running
test "validate_jac returns error envelope when server is unreachable" {
    w = root spawn validate_jac(code="node Foo {}");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "list_examples returns error envelope when server is unreachable" {
    w = root spawn list_examples();
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "set_mcp_server rejects unreachable URL" {
    w = root spawn set_mcp_server(server_url="http://127.0.0.1:19999/mcp/");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for unreachable URL";
    assert result["tool"] == "set_mcp_server" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

# Single report contract
test "validate_jac guard produces exactly one report" {
    w = root spawn validate_jac(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "check_syntax guard produces exactly one report" {
    w = root spawn check_syntax(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "format_jac guard produces exactly one report" {
    w = root spawn format_jac(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "py_to_jac guard produces exactly one report" {
    w = root spawn py_to_jac(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "get_ast guard produces exactly one report" {
    w = root spawn get_ast(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "explain_error guard produces exactly one report" {
    w = root spawn explain_error(error_message="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "get_example guard produces exactly one report" {
    w = root spawn get_example(name="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

test "search_docs guard produces exactly one report" {
    w = root spawn search_docs(query="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# set_mcp_server — no empty-URL guard
test "set_mcp_server with empty URL returns error response" {
    w = root spawn set_mcp_server(server_url="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty URL";
    assert result["tool"] == "set_mcp_server" , f"Got tool: '{result['tool']}'";
    assert "message" in result["error"] , "Expected an error message";
}

# get_ast — empty-code guard is format-independent
test "get_ast empty code guard fires with format json" {
    w = root spawn get_ast(code="", format="json");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code with format=json";
    assert result["tool"] == "get_ast" , f"Got tool: '{result['tool']}'";
}
