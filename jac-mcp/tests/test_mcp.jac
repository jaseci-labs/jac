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
    assert "get_ast" in names;
    assert "lint_jac" in names;
    assert "jac_to_py" in names;
    assert "jac_to_js" in names;
    assert "run_jac" in names;
    assert "graph_visualize" in names;
    assert "list_commands" in names;
    assert "get_command" in names;
    assert "execute_command" in names;
    assert "understand_jac_and_jaseci" in names;
    assert "get_resource" in names;
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

test "list examples returns results when repo root is None (PyPI install)" {
    import from unittest.mock { patch, MagicMock }

    # Mock find_repo_root to return None, simulating a PyPI (non-editable) install
    with patch("jac_mcp.resources.find_repo_root", return_value=None) {
        tp = ToolProvider();
        result = tp.call_tool("list_examples", {});
    }
    assert "examples" in result;
    examples = result["examples"];
    assert len(examples) > 0 , "list_examples should return results via GitHub fallback when repo root is None";
    names = [e["name"] for e in examples];
    assert "data_spatial" in names , "Expected 'data_spatial' in GitHub-fetched examples";
    for ex in examples {
        assert "name" in ex;
        assert "uri" in ex;
        assert ex["uri"].startswith("jac://examples/");
    }
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
    assert result["valid"] == True;
    assert len(result["errors"]) == 0;
}

test "parse invalid code" {
    result = CompilerBridge.parse_snippet("this is not valid @@@ !!!");
    assert isinstance(result, dict);
    assert result["valid"] == False;
    assert len(result["errors"]) > 0;
}

test "parse errors have correct line and col" {
    result = CompilerBridge.parse_snippet("obj Foo {\n    has x: int = 5\n}");
    assert result["valid"] == False;
    assert len(result["errors"]) > 0;
    err = result["errors"][0];
    assert err["line"] > 0 , f"Expected line > 0, got {err['line']}";
    assert err["col"] > 0 , f"Expected col > 0, got {err['col']}";
    assert "message" in err;
    assert len(err["message"]) > 0;
    assert isinstance(err["line"], int);
    assert isinstance(err["col"], int);
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

test "get ast tree format" {
    result = CompilerBridge.get_ast_snippet("obj Foo { has x: int = 5; }", "tree");
    assert isinstance(result, dict);
    assert result.get("ast") is not None;
    assert result.get("valid") == True;
    assert "Foo" in result["ast"];
}

test "get ast json format" {
    result = CompilerBridge.get_ast_snippet("obj Foo { has x: int = 5; }", "json");
    assert isinstance(result, dict);
    assert result.get("ast") is not None;
    assert result.get("valid") == True;
    assert "Module" in result["ast"];
}

test "get ast invalid code" {
    result = CompilerBridge.get_ast_snippet("this is not valid @@@ !!!", "tree");
    assert isinstance(result, dict);
    assert result.get("ast") is not None;
    assert result.get("valid") == False;
    assert len(result.get("errors", [])) > 0;
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
    assert result["messages"][0]["role"] == "assistant";
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

# ── Plugin Config / jac.toml Integration Tests ──
#   CLI (explicit) > [plugins.mcp] in jac.toml > CLI default
test "jac.toml values override CLI defaults for all three fields" {
    import from unittest.mock { patch, MagicMock }
    import from jac_mcp.plugin { _handle_mcp_cmd }

    mock_jac_cfg = MagicMock();
    mock_jac_cfg.get_plugin_config.return_value = {
        "transport": "streamable-http",
        "port": 9000,
        "host": "0.0.0.0"
    };

    # Simulate: user ran `jac mcp` with no explicit args (all CLI defaults)
    mock_ctx = MagicMock();
    def cli_no_args(name: str, fallback: object = None) -> object {
        m = {"transport": "stdio", "port": 3001, "host": "127.0.0.1", "inspect": False};
        if name in m {
            return m[name];
        }
        return fallback;
    }
    mock_ctx.get_arg.side_effect = cli_no_args;

    captured: list = [];
    def capture_ctor(**kwargs: object) -> object {
        captured.append(kwargs);
        return MagicMock();
    }
    mock_server_cls = MagicMock();
    mock_server_cls.side_effect = capture_ctor;

    with patch("jaclang.project.config.get_config", return_value=mock_jac_cfg) {
        with patch("jac_mcp.server.JacMcpServer", mock_server_cls) {
            _handle_mcp_cmd(mock_ctx);
        }
    }
    assert len(captured) == 1 , "JacMcpServer should have been instantiated once";
    ctor_kwargs = captured[0];
    assert ctor_kwargs["transport"] == "streamable-http" , "jac.toml transport should override CLI default";
    assert ctor_kwargs["port"] == 9000 , "jac.toml port should override CLI default";
    assert ctor_kwargs["host"] == "0.0.0.0" , "jac.toml host should override CLI default";
}

test "explicit CLI args take priority over jac.toml for all three fields" {
    import from unittest.mock { patch, MagicMock }
    import from jac_mcp.plugin { _handle_mcp_cmd }

    mock_jac_cfg = MagicMock();
    mock_jac_cfg.get_plugin_config.return_value = {
        "transport": "streamable-http",
        "port": 9000,
        "host": "0.0.0.0"
    };

    # Simulate: user ran `jac mcp --transport sse --port 8080 --host 10.0.0.1`
    mock_ctx = MagicMock();
    def cli_explicit(name: str, fallback: object = None) -> object {
        m = {"transport": "sse", "port": 8080, "host": "10.0.0.1", "inspect": False};
        if name in m {
            return m[name];
        }
        return fallback;
    }
    mock_ctx.get_arg.side_effect = cli_explicit;

    captured: list = [];
    def capture_ctor(**kwargs: object) -> object {
        captured.append(kwargs);
        return MagicMock();
    }
    mock_server_cls = MagicMock();
    mock_server_cls.side_effect = capture_ctor;

    with patch("jaclang.project.config.get_config", return_value=mock_jac_cfg) {
        with patch("jac_mcp.server.JacMcpServer", mock_server_cls) {
            _handle_mcp_cmd(mock_ctx);
        }
    }
    assert len(captured) == 1;
    ctor_kwargs = captured[0];
    assert ctor_kwargs["transport"] == "sse" , "explicit CLI --transport must win over jac.toml";
    assert ctor_kwargs["port"] == 8080 , "explicit CLI --port must win over jac.toml";
    assert ctor_kwargs["host"] == "10.0.0.1" , "explicit CLI --host must win over jac.toml";
}

test "CLI defaults used when jac.toml has no mcp section" {
    import from unittest.mock { patch, MagicMock }
    import from jac_mcp.plugin { _handle_mcp_cmd }

    mock_jac_cfg = MagicMock();
    mock_jac_cfg.get_plugin_config.return_value = {};

    mock_ctx = MagicMock();
    def cli_no_args(name: str, fallback: object = None) -> object {
        m = {"transport": "stdio", "port": 3001, "host": "127.0.0.1", "inspect": False};
        if name in m {
            return m[name];
        }
        return fallback;
    }
    mock_ctx.get_arg.side_effect = cli_no_args;

    captured: list = [];
    def capture_ctor(**kwargs: object) -> object {
        captured.append(kwargs);
        return MagicMock();
    }
    mock_server_cls = MagicMock();
    mock_server_cls.side_effect = capture_ctor;

    with patch("jaclang.project.config.get_config", return_value=mock_jac_cfg) {
        with patch("jac_mcp.server.JacMcpServer", mock_server_cls) {
            _handle_mcp_cmd(mock_ctx);
        }
    }
    assert len(captured) == 1;
    ctor_kwargs = captured[0];
    assert ctor_kwargs["transport"] == "stdio";
    assert ctor_kwargs["port"] == 3001;
    assert ctor_kwargs["host"] == "127.0.0.1";
}

test "CLI defaults used when no jac.toml is present" {
    import from unittest.mock { patch, MagicMock }
    import from jac_mcp.plugin { _handle_mcp_cmd }

    mock_ctx = MagicMock();
    def cli_no_args(name: str, fallback: object = None) -> object {
        m = {"transport": "stdio", "port": 3001, "host": "127.0.0.1", "inspect": False};
        if name in m {
            return m[name];
        }
        return fallback;
    }
    mock_ctx.get_arg.side_effect = cli_no_args;

    captured: list = [];
    def capture_ctor(**kwargs: object) -> object {
        captured.append(kwargs);
        return MagicMock();
    }
    mock_server_cls = MagicMock();
    mock_server_cls.side_effect = capture_ctor;

    with patch("jaclang.project.config.get_config", return_value=None) {
        with patch("jac_mcp.server.JacMcpServer", mock_server_cls) {
            _handle_mcp_cmd(mock_ctx);
        }
    }
    assert len(captured) == 1;
    ctor_kwargs = captured[0];
    assert ctor_kwargs["transport"] == "stdio";
    assert ctor_kwargs["port"] == 3001;
    assert ctor_kwargs["host"] == "127.0.0.1";
}

test "all prompt messages use only MCP-valid roles" {
    pp = PromptProvider();
    valid_roles = ["user", "assistant"];
    for prompt in pp.list_prompts() {
        args: dict = {};
        for arg in prompt.get("arguments", []) {
            args[arg["name"]] = "test";
        }
        result = pp.get_prompt(prompt["name"], args);
        for msg in result.get("messages", []) {
            assert msg["role"] in valid_roles , f"Prompt '{prompt[
                'name'
            ]}' has invalid MCP role '{msg[
                'role'
            ]}' — only 'user' or 'assistant' are allowed";
        }
    }
}

test "prompt messages pass MCP SDK Pydantic validation" {
    import from mcp.types { PromptMessage, TextContent }
    pp = PromptProvider();
    for prompt in pp.list_prompts() {
        args: dict = {};
        for arg in prompt.get("arguments", []) {
            args[arg["name"]] = "test";
        }
        result = pp.get_prompt(prompt["name"], args);
        for msg in result.get("messages", []) {
            pm = PromptMessage(
                role=msg["role"], content=TextContent(type="text", text=msg["content"])
            );
            assert pm is not None , f"PromptMessage construction failed for prompt '{prompt[
                'name'
            ]}' with role '{msg['role']}'";
        }
    }
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

# ── Compiler Bridge — New Tool Tests ──
glob _VALID_JAC = "obj Foo { has x: int = 5; }",
     _GRAPH_JAC = "node A { has val: int = 1; }\nwith entry { a = A(val=1); root ++> a; }",
     _CLIENT_JAC = "def:pub greet(name: str) -> str { return name; }";

test "lint snippet clean code" {
    result = CompilerBridge.lint_snippet(_VALID_JAC);
    assert "violations" in result;
    assert "changed" in result;
    assert isinstance(result["violations"], list);
}

test "lint snippet auto fix" {
    result = CompilerBridge.lint_snippet(_VALID_JAC, auto_fix=True);
    assert "violations" in result;
    assert "fixed_code" in result;
    assert "changed" in result;
}

test "jac to py produces python" {
    result = CompilerBridge.jac_to_py(_VALID_JAC);
    assert "python_code" in result;
    assert "warnings" in result;
    assert isinstance(result["python_code"], str);
}

test "jac to py invalid code" {
    result = CompilerBridge.jac_to_py("this @@@ is broken");
    assert "python_code" in result;
    assert result["python_code"] == "";
}

test "jac to js client code shape" {
    result = CompilerBridge.jac_to_js(_CLIENT_JAC);
    assert "js_code" in result;
    assert "warnings" in result;
    assert isinstance(result["js_code"], str);
}

test "run snippet prints hello" {
    result = CompilerBridge.run_snippet("with entry { print(\"hello\"); }");
    assert "stdout" in result;
    assert "exit_code" in result;
    assert result["exit_code"] == 0;
    assert "hello" in result["stdout"];
}

test "run snippet invalid code fails" {
    result = CompilerBridge.run_snippet("this @@@ is broken");
    assert "exit_code" in result;
    assert result["exit_code"] != 0;
}

test "graph viz snippet dot format" {
    result = CompilerBridge.graph_viz_snippet(_GRAPH_JAC);
    assert "graph" in result;
    assert isinstance(result["graph"], str);
}

test "graph viz snippet mermaid format" {
    result = CompilerBridge.graph_viz_snippet(_GRAPH_JAC, format="mermaid");
    assert "graph" in result;
    assert isinstance(result["graph"], str);
}

test "list templates has default" {
    result = CompilerBridge.list_templates();
    assert "templates" in result;
    assert len(result["templates"]) > 0;
    names = [t["name"] for t in result["templates"]];
    assert "default" in names;
    for t in result["templates"] {
        assert "name" in t;
        assert "description" in t;
    }
}

test "create project empty name returns error" {
    result = CompilerBridge.create_project("");
    assert not result["success"];
    assert "error" in result;
}

test "create project default template" {
    import tempfile;
    tmpdir = tempfile.mkdtemp();
    result = CompilerBridge.create_project("myapp", directory=tmpdir);
    assert "success" in result;
    assert "project_path" in result;
    assert "files_created" in result;
    if result["success"] {
        assert len(result["files_created"]) > 0;
        assert any("main.jac" in f for f in result["files_created"]);
    }
}

test "start server nonexistent file" {
    result = CompilerBridge.start_server("/nonexistent/path/app.jac");
    assert "error" in result;
}

test "start server faux mode" {
    import from jac_mcp.resources { find_repo_root }
    import from pathlib { Path }

    repo_root = find_repo_root();
    if repo_root is None {
        return;
    }
    main_jac = str(
        Path(repo_root) / "jac-mcp" / "tests" / "fixtures" / "sample_project" / "main.jac"
    );
    result = CompilerBridge.start_server(main_jac, port=19999, faux=True);
    assert "mode" in result;
    assert result["mode"] == "faux";
    assert "endpoints" in result;
}

# ── Tool Provider — New Tool Tests ──
test "get ast via tool" {
    tp = ToolProvider();
    result = tp.call_tool("get_ast", {"code": _VALID_JAC});
    assert "ast" in result;
    assert "valid" in result;
}

test "get ast missing code returns error" {
    tp = ToolProvider();
    result = tp.call_tool("get_ast", {});
    assert "error" in result;
}

test "lint jac via tool" {
    tp = ToolProvider();
    result = tp.call_tool("lint_jac", {"code": _VALID_JAC});
    assert "violations" in result;
    assert isinstance(result["violations"], list);
}

test "lint jac auto fix via tool" {
    tp = ToolProvider();
    result = tp.call_tool("lint_jac", {"code": _VALID_JAC, "auto_fix": True});
    assert "violations" in result;
    assert "fixed_code" in result;
    assert "changed" in result;
}

test "lint jac missing code returns error" {
    tp = ToolProvider();
    result = tp.call_tool("lint_jac", {});
    assert "error" in result;
}

test "jac to py via tool" {
    tp = ToolProvider();
    result = tp.call_tool("jac_to_py", {"code": _VALID_JAC});
    assert "python_code" in result;
    assert "warnings" in result;
}

test "jac to js via tool" {
    tp = ToolProvider();
    result = tp.call_tool("jac_to_js", {"code": _CLIENT_JAC});
    assert "js_code" in result;
    assert "warnings" in result;
}

test "run jac prints output" {
    tp = ToolProvider();
    result = tp.call_tool("run_jac", {"code": "with entry { print(\"hello world\"); }"});
    assert "stdout" in result;
    assert "exit_code" in result;
    assert result["exit_code"] == 0;
    assert "hello world" in result["stdout"];
}

test "run jac invalid code" {
    tp = ToolProvider();
    result = tp.call_tool("run_jac", {"code": "this @@@ is broken"});
    assert "exit_code" in result or "error" in result;
}

test "run jac missing code returns error" {
    tp = ToolProvider();
    result = tp.call_tool("run_jac", {});
    assert "error" in result;
}

test "graph visualize returns dot" {
    tp = ToolProvider();
    result = tp.call_tool("graph_visualize", {"code": _GRAPH_JAC});
    assert "graph" in result;
    assert isinstance(result["graph"], str);
}

test "graph visualize missing code returns error" {
    tp = ToolProvider();
    result = tp.call_tool("graph_visualize", {});
    assert "error" in result;
}

test "get command returns full args" {
    tp = ToolProvider();
    result = tp.call_tool("get_command", {"name": "run"});
    assert "name" in result;
    assert result["name"] == "run";
    assert "args" in result;
    assert isinstance(result["args"], list);
    assert len(result["args"]) > 0;
}

test "get command unknown returns error" {
    tp = ToolProvider();
    result = tp.call_tool("get_command", {"name": "nonexistent_cmd"});
    assert "error" in result;
}

test "get command missing name returns error" {
    tp = ToolProvider();
    result = tp.call_tool("get_command", {});
    assert "error" in result;
}

test "understand returns knowledge map with key sections and size hints" {
    tp = ToolProvider();
    result = tp.call_tool("understand_jac_and_jaseci", {});
    assert "knowledge_map" in result;
    km = result["knowledge_map"];
    assert "Language Syntax" in km
    and "Object-Spatial Programming" in km
    and "Full-Stack Development" in km;
    assert "jac://guide/pitfalls" in km and "jac://docs/osp" in km;
    assert "[S]" in km and "[M]" in km and "[L]" in km;
}

test "get resource fetches valid URIs and rejects invalid ones" {
    tp = ToolProvider();
    pitfalls = tp.call_tool("get_resource", {"uri": "jac://guide/pitfalls"});
    assert "content" in pitfalls and "WRONG" in pitfalls["content"];
    osp = tp.call_tool("get_resource", {"uri": "jac://docs/osp"});
    assert "content" in osp and osp["uri"] == "jac://docs/osp";
    bad = tp.call_tool("get_resource", {"uri": "jac://nonexistent/fake"});
    assert "error" in bad;
    empty = tp.call_tool("get_resource", {});
    assert "error" in empty;
}
