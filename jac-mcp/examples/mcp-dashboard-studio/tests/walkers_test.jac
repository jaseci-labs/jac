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
    search_docs,
    jac_to_js,
    jac_to_py,
    run_jac,
    lint_jac,
    graph_visualize,
    list_commands,
    get_command,
    execute_command,
    understand_jac_and_jaseci,
    get_resource
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

# ---------------------------------------------------------------------------
# jac_to_js
# ---------------------------------------------------------------------------
test "jac_to_js rejects empty code" {
    w = root spawn jac_to_js(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "jac_to_js" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "jac_to_js rejects whitespace-only code" {
    w = root spawn jac_to_js(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

test "jac_to_js returns error envelope when server is unreachable" {
    w = root spawn jac_to_js(code="obj Foo { has x: int = 1; }");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "jac_to_js guard produces exactly one report" {
    w = root spawn jac_to_js(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# jac_to_py
# ---------------------------------------------------------------------------
test "jac_to_py rejects empty code" {
    w = root spawn jac_to_py(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "jac_to_py" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "jac_to_py rejects whitespace-only code" {
    w = root spawn jac_to_py(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

test "jac_to_py returns error envelope when server is unreachable" {
    w = root spawn jac_to_py(code="obj Foo { has x: int = 1; }");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "jac_to_py guard produces exactly one report" {
    w = root spawn jac_to_py(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# run_jac
# ---------------------------------------------------------------------------
test "run_jac rejects empty code" {
    w = root spawn run_jac(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "run_jac" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "run_jac rejects whitespace-only code" {
    w = root spawn run_jac(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

test "run_jac returns error envelope when server is unreachable" {
    w = root spawn run_jac(code="with entry { print('hi'); }");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "run_jac guard produces exactly one report" {
    w = root spawn run_jac(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# lint_jac
# ---------------------------------------------------------------------------
test "lint_jac rejects empty code" {
    w = root spawn lint_jac(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "lint_jac" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "lint_jac rejects whitespace-only code" {
    w = root spawn lint_jac(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

test "lint_jac returns error envelope when server is unreachable" {
    w = root spawn lint_jac(code="obj Foo { has x: int = 1; }");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "lint_jac guard produces exactly one report" {
    w = root spawn lint_jac(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# graph_visualize
# ---------------------------------------------------------------------------
test "graph_visualize rejects empty code" {
    w = root spawn graph_visualize(code="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty code";
    assert result["tool"] == "graph_visualize" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "graph_visualize rejects whitespace-only code" {
    w = root spawn graph_visualize(code="   \n\t  ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only code";
}

test "graph_visualize returns error envelope when server is unreachable" {
    w = root spawn graph_visualize(code="obj Foo { has x: int = 1; }");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "graph_visualize guard produces exactly one report" {
    w = root spawn graph_visualize(code="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# get_command
# ---------------------------------------------------------------------------
test "get_command rejects empty name" {
    w = root spawn get_command(name="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty name";
    assert result["tool"] == "get_command" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "get_command rejects whitespace-only name" {
    w = root spawn get_command(name="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only name";
}

test "get_command returns error envelope when server is unreachable" {
    w = root spawn get_command(name="run");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "get_command guard produces exactly one report" {
    w = root spawn get_command(name="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# execute_command
# ---------------------------------------------------------------------------
test "execute_command rejects empty command" {
    w = root spawn execute_command(command="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty command";
    assert result["tool"] == "execute_command" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "execute_command rejects whitespace-only command" {
    w = root spawn execute_command(command="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only command";
}

test "execute_command returns error envelope when server is unreachable" {
    w = root spawn execute_command(command="run", args=["main.jac"]);
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "execute_command guard produces exactly one report" {
    w = root spawn execute_command(command="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# get_resource
# ---------------------------------------------------------------------------
test "get_resource rejects empty uri" {
    w = root spawn get_resource(uri="");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for empty uri";
    assert result["tool"] == "get_resource" , f"Got tool: '{result['tool']}'";
    assert result["error"]["message"] != "" , "Expected a non-empty error message";
}

test "get_resource rejects whitespace-only uri" {
    w = root spawn get_resource(uri="   ");
    result = w.reports[0];
    assert not result["ok"] , "Expected ok: false for whitespace-only uri";
}

test "get_resource returns error envelope when server is unreachable" {
    w = root spawn get_resource(uri="jac://docs/osp");
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "get_resource guard produces exactly one report" {
    w = root spawn get_resource(uri="");
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# list_commands — no required inputs, graceful failure + single report only
# ---------------------------------------------------------------------------
test "list_commands returns error envelope when server is unreachable" {
    w = root spawn list_commands();
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "list_commands produces exactly one report" {
    w = root spawn list_commands();
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}

# ---------------------------------------------------------------------------
# understand_jac_and_jaseci — no required inputs, graceful failure + single report only
# ---------------------------------------------------------------------------
test "understand_jac_and_jaseci returns error envelope when server is unreachable" {
    w = root spawn understand_jac_and_jaseci();
    result = w.reports[0];
    assert "ok" in result , "Missing 'ok' key";
    assert "tool" in result , "Missing 'tool' key";
    assert "data" in result , "Missing 'data' key";
    assert "error" in result , "Missing 'error' key";
    assert not result["ok"] , "Should fail gracefully with no server running";
}

test "understand_jac_and_jaseci produces exactly one report" {
    w = root spawn understand_jac_and_jaseci();
    assert len(w.reports) == 1 , f"Expected 1 report, got {len(w.reports)}";
}
