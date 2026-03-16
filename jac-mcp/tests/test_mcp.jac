"""Tests for jac-mcp plugin."""

import from jac_mcp.server { JacMcpServer }
import from jac_mcp.plugin_config { JacMcpPluginConfig }
import from jac_mcp.resources { ResourceProvider }
import from jac_mcp.tools { ToolProvider }
import from jac_mcp.prompts { PromptProvider }
import from jac_mcp.compiler_bridge { CompilerBridge }

# ── Server Tests ──
test "server creation with defaults" {
    server = JacMcpServer();
    assert server.transport == "stdio";
    assert server.port == 3001;
    assert server.host == "127.0.0.1";
}

test "server creation with custom config" {
    server = JacMcpServer(transport="sse", port=8080, host="0.0.0.0");
    assert server.transport == "sse";
    assert server.port == 8080;
    assert server.host == "0.0.0.0";
}

test "streamable-http transport initializes session manager and app" {
    import from mcp.server { Server }
    import from mcp.server.streamable_http_manager { StreamableHTTPSessionManager }
    import from starlette.applications { Starlette }
    import from starlette.routing { Mount }
    import contextlib;

    server = Server("test-server");
    session_manager = StreamableHTTPSessionManager(
        app=server, json_response=True, stateless=False
    );
    assert session_manager is not None;

    @contextlib.asynccontextmanager
    async def lifespan(app: object) -> object {
        async with session_manager.run() {
            yield ;
        }
    }

    starlette_app = Starlette(
        lifespan=lifespan, routes=[Mount("/mcp", app=session_manager.handle_request)]
    );
    assert starlette_app is not None;
    assert starlette_app.routes[0].path == "/mcp";
}

test "sse _async_start builds correct Mount-based route for messages" {
    import from unittest.mock { patch, AsyncMock, MagicMock }
    import from jac_mcp.server { JacMcpServer }
    import from starlette.routing { Mount, Route }

    captured_apps: list = [];

    def fake_config(app: object, **kwargs: object) -> object {
        captured_apps.append(app);
        return MagicMock();
    }

    mock_serve = AsyncMock();
    mock_server_instance = MagicMock();
    mock_server_instance.serve = mock_serve;
    mock_server_class = MagicMock();
    mock_server_class.return_value = mock_server_instance;

    mock_config_class = MagicMock();
    mock_config_class.side_effect = fake_config;

    # Pass mocks as positional arg (maps to patch's 'new' parameter)
    with patch("uvicorn.Config", mock_config_class) {
        with patch("uvicorn.Server", mock_server_class) {
            JacMcpServer(transport="sse", port=3001, host="127.0.0.1").start();
        }
    }

    assert len(captured_apps) == 1 , "uvicorn.Config should have been called once";
    app: object = captured_apps[0];
    routes: list = getattr(app, "routes");
    assert len(routes) >= 2;

    sse_route: object = routes[0];
    messages_route: object = routes[1];
    assert isinstance(sse_route, Route) , f"Expected Route for /sse, got {type(
        sse_route
    )}";
    assert getattr(sse_route, "path") == "/sse";
    assert isinstance(messages_route, Mount) , (
        f"Expected Mount for /messages (handle_post_message is an ASGI app, "
        f"not a Starlette endpoint — use Mount not Route). Got {type(messages_route)}"
    );
    assert getattr(messages_route, "path") == "/messages";
}

# ── Plugin Config Tests ──
test "get plugin metadata" {
    metadata = JacMcpPluginConfig.get_plugin_metadata();
    assert metadata["name"] == "mcp";
    assert metadata["version"] == "0.1.0";
    assert "description" in metadata;
}

test "get config schema" {
    schema = JacMcpPluginConfig.get_config_schema();
    assert schema["section"] == "mcp";
    assert "options" in schema;
    options = schema["options"];
    assert "transport" in options;
    assert "port" in options;
    assert "host" in options;
    assert "expose_grammar" in options;
    assert "enable_validate" in options;
}

# ── Resource Provider Tests ──
test "index creates resources" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    assert len(resources) > 0;
}

test "grammar spec exists" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    uris = [r["uri"] for r in resources];
    assert "jac://grammar/spec" in uris;
}

test "grammar spec content" {
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource("jac://grammar/spec");
    assert content;
    assert "module" in content.lower() or "::=" in content;
}

test "grammar tokens exists" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    uris = [r["uri"] for r in resources];
    assert "jac://grammar/tokens" in uris;
}

test "docs foundation exists" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    uris = [r["uri"] for r in resources];
    assert "jac://docs/foundation" in uris;
}

test "docs foundation content" {
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource("jac://docs/foundation");
    assert content;
    assert len(content) > 100;
}

test "examples index exists" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    uris = [r["uri"] for r in resources];
    assert "jac://examples/index" in uris;
}

test "examples index content" {
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource("jac://examples/index");
    assert content;
    assert "data_spatial" in content;
}

test "invalid uri returns error" {
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource("jac://nonexistent/resource");
    assert content.startswith("Error:");
}

test "all doc resources readable" {
    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    doc_resources = [
        r
        for r in resources
        if r["uri"].startswith("jac://docs/")
    ];
    assert len(doc_resources) >= 5;
    for r in doc_resources {
        content = rp.read_resource(r["uri"]);
        assert not content.startswith("Error:");
        assert len(content) > 0;
    }
}

test "example category readable" {
    rp = ResourceProvider();
    rp.index_resources();
    content = rp.read_resource("jac://examples/data_spatial");
    if not content.startswith("Error:") {
        assert ".jac" in content.lower() or "---" in content;
    }
}

# ── Tool Provider Tests ──
test "list tools returns tools" {
    tp = ToolProvider();
    tools = tp.list_tools();
    assert len(tools) > 0;
}

test "all tools have required fields" {
    tp = ToolProvider();
    tools = tp.list_tools();
    for tool in tools {
        assert "name" in tool;
        assert "description" in tool;
        assert "inputSchema" in tool;
    }
}

test "tool names" {
    tp = ToolProvider();
    tools = tp.list_tools();
    names = [t["name"] for t in tools];
    assert "validate_jac" in names;
    assert "check_syntax" in names;
    assert "format_jac" in names;
    assert "py_to_jac" in names;
    assert "explain_error" in names;
    assert "list_examples" in names;
    assert "get_example" in names;
    assert "search_docs" in names;
}

test "explain error unexpected token" {
    tp = ToolProvider();
    result = tp.call_tool(
        "explain_error", {"error_message": "unexpected token 'class'"}
    );
    assert "explanation" in result;
    assert "suggestion" in result;
}

test "explain error undefined name" {
    tp = ToolProvider();
    result = tp.call_tool(
        "explain_error", {"error_message": "name 'foo' is not defined"}
    );
    assert "explanation" in result;
}

test "explain error type mismatch" {
    tp = ToolProvider();
    result = tp.call_tool(
        "explain_error", {"error_message": "type mismatch: expected int, got str"}
    );
    assert "explanation" in result;
}

test "list examples returns results" {
    tp = ToolProvider();
    result = tp.call_tool("list_examples", {});
    assert "examples" in result;
    assert isinstance(result["examples"], list);
}

test "unknown tool returns error" {
    tp = ToolProvider();
    result = tp.call_tool("nonexistent_tool", {});
    assert "error" in result;
}

test "missing required arg returns error" {
    tp = ToolProvider();
    result = tp.call_tool("validate_jac", {});
    assert "error" in result;
}

test "search docs" {
    tp = ToolProvider();
    result = tp.call_tool("search_docs", {"query": "walker node"});
    assert "results" in result;
    assert isinstance(result["results"], list);
}

# ── Compiler Bridge Tests ──
test "parse valid code" {
    result = CompilerBridge.parse_snippet("obj Foo { has x: int = 5; }");
    assert isinstance(result, dict);
    assert "valid" in result;
    assert "errors" in result;
}

test "parse empty code" {
    result = CompilerBridge.parse_snippet("");
    assert isinstance(result, dict);
}

test "input size limit" {
    large_input = "x = 1;\n" * 20000;
    result = CompilerBridge.parse_snippet(large_input);
    assert result["valid"] == False;
    assert len(result["errors"]) > 0;
    assert "size" in result["errors"][0]["message"].lower();
}

test "format valid code" {
    result = CompilerBridge.format_snippet("obj Foo { has x: int = 5; }");
    assert isinstance(result, dict);
    assert "formatted" in result;
}

test "py to jac basic" {
    result = CompilerBridge.py_to_jac("x = 5\nprint(x)");
    assert isinstance(result, dict);
    assert "jac_code" in result;
    assert "warnings" in result;
}

# ── Prompt Provider Tests ──
test "list prompts returns prompts" {
    pp = PromptProvider();
    prompts = pp.list_prompts();
    assert len(prompts) > 0;
}

test "all prompts have required fields" {
    pp = PromptProvider();
    prompts = pp.list_prompts();
    for prompt in prompts {
        assert "name" in prompt;
        assert "description" in prompt;
        assert "arguments" in prompt;
    }
}

test "prompt names" {
    pp = PromptProvider();
    prompts = pp.list_prompts();
    names = [p["name"] for p in prompts];
    assert "write_module" in names;
    assert "write_impl" in names;
    assert "write_walker" in names;
    assert "write_node" in names;
    assert "write_test" in names;
    assert "write_ability" in names;
    assert "debug_error" in names;
    assert "fix_type_error" in names;
    assert "migrate_python" in names;
}

test "write module returns messages" {
    pp = PromptProvider();
    result = pp.get_prompt(
        "write_module", {"name": "my_module", "purpose": "manage user data"}
    );
    assert "messages" in result;
    assert len(result["messages"]) > 0;
    assert result["messages"][0]["role"] == "system";
    assert result["messages"][1]["role"] == "user";
    assert "my_module" in result["messages"][1]["content"];
}

test "write module with impl" {
    pp = PromptProvider();
    result = pp.get_prompt(
        "write_module",
        {"name": "calc", "purpose": "basic calculations", "has_impl": "true"}
    );
    content = result["messages"][1]["content"];
    assert "impl" in content.lower();
}

test "write walker returns messages" {
    pp = PromptProvider();
    result = pp.get_prompt(
        "write_walker",
        {
            "name": "data_collector",
            "purpose": "collect data from graph nodes",
            "node_types": "DataNode, SummaryNode"
        }
    );
    assert "messages" in result;
    assert "data_collector" in result["messages"][1]["content"];
}

test "debug error includes context" {
    pp = PromptProvider();
    result = pp.get_prompt(
        "debug_error", {"error_output": "unexpected token", "code": "class Foo:"}
    );
    content = result["messages"][1]["content"];
    assert "Jac" in content;
}

test "migrate python returns messages" {
    pp = PromptProvider();
    result = pp.get_prompt(
        "migrate_python",
        {"python_code": "class Foo:\n    def __init__(self):\n        self.x = 5"}
    );
    assert "messages" in result;
    content = result["messages"][1]["content"];
    assert "class Foo" in content;
}

test "unknown prompt returns error" {
    pp = PromptProvider();
    result = pp.get_prompt("nonexistent", {});
    assert "Unknown" in result.get("description", "") or "messages" in result;
}

# ── Bundle Script Tests ──
"""Verify every DOC_MAPPINGS entry points to a real file in docs/."""
test "all doc mapping source files exist" {
    import from jac_mcp.resources { find_repo_root, DOC_MAPPINGS }
    import from pathlib { Path }

    repo_root = find_repo_root();
    if repo_root is None {
        # Skip in non-repo (PyPI) environments
        return;
    }
    docs_dir = Path(repo_root) / "docs" / "docs";
    missing: list[str] = [];
    for (uri, mapping) in DOC_MAPPINGS.items() {
        (rel_path, bundled_name, desc) = mapping;
        full_path = docs_dir / rel_path;
        if not full_path.exists() {
            missing.append(f"{uri} -> {rel_path}");
        }
    }
    assert len(missing) == 0 , f"Missing doc files: {missing}";
}

"""Verify the bundle_docs.jac script exits 0."""
test "bundle script runs successfully" {
    import subprocess;
    import from pathlib { Path }
    import from jac_mcp.resources { find_repo_root }

    repo_root = find_repo_root();
    if repo_root is None {
        return;
    }
    script = Path(repo_root) / "jac-mcp" / "scripts" / "bundle_docs.jac";
    if not script.exists() {
        return;
    }
    result = subprocess.run(
        ["jac", "run", str(script)], capture_output=True, text=True, timeout=60
    );
    assert result.returncode == 0 , f"bundle_docs.jac failed:\n{result.stdout}\n{result.stderr}";
}

"""Verify no two DOC_MAPPINGS entries share the same bundled filename."""
test "doc mappings have unique bundled names" {
    import from jac_mcp.resources { DOC_MAPPINGS }

    seen: dict[str, str] = {};
    dupes: list[str] = [];
    for (uri, mapping) in DOC_MAPPINGS.items() {
        bundled_name = mapping[1];
        if bundled_name in seen {
            dupes.append(f"{bundled_name}: {seen[bundled_name]} vs {uri}");
        } else {
            seen[bundled_name] = uri;
        }
    }
    assert len(dupes) == 0 , f"Duplicate bundled names: {dupes}";
}
