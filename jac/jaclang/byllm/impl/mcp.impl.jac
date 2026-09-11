import from concurrent.futures { Future }
import from contextlib { AbstractAsyncContextManager }

obj _McpState {
    has loop: (asyncio.AbstractEventLoop | None) = None,
        thread: (threading.Thread | None) = None,
        session: (AbstractAsyncContextManager | None) = None,
        session_ctx: (AbstractAsyncContextManager | None) = None,
        transport_ctx: (AbstractAsyncContextManager | None) = None,
        tools_cache: list[McpTool] = [],
        connected: bool = False,
        _lock: threading.Lock postinit;

    def postinit -> None;
    def start_loop -> None;
    def run_text(coro: Coroutine[any, any, str]) -> str;
    def run_task(coro: Coroutine[any, any, None]) -> None;
    def stop -> None;
}

impl _McpState.postinit -> None {
    self._lock = threading.Lock();
}

impl _McpState.start_loop -> None {
    loop = asyncio.new_event_loop();
    thread = threading.Thread(target=loop.run_forever, daemon=True);
    self.loop = loop;
    self.thread = thread;
    thread.start();
}

impl _McpState.run_text(coro: Coroutine[any, any, str]) -> str {
    loop = self.loop;
    if loop is None {
        raise McpError(message="MCP event loop is not running.");
    }
    with self._lock {
        future = asyncio.run_coroutine_threadsafe(coro, loop);
        assert isinstance(future, Future);
        text: str = future.result(timeout=120);
        return text;
    }
}

impl _McpState.run_task(coro: Coroutine[any, any, None]) -> None {
    loop = self.loop;
    if loop is None {
        raise McpError(message="MCP event loop is not running.");
    }
    with self._lock {
        future = asyncio.run_coroutine_threadsafe(coro, loop);
        assert isinstance(future, Future);
        future.result(timeout=120);
    }
}

impl _McpState.stop -> None {
    loop = self.loop;
    thread = self.thread;
    if loop is not None and loop.is_running() {
        try {
            self.run_task(_async_cleanup(self));
        } except Exception as e {
            logger.debug(f"MCP cleanup failed: {e}");
        }
        loop.call_soon_threadsafe(loop.stop);
    }
    if thread is not None and thread.is_alive() {
        thread.join(timeout=5);
    }
    if loop is not None and not loop.is_closed() {
        loop.close();
    }
    self.loop = None;
    self.thread = None;
    self.session = None;
    self.session_ctx = None;
    self.transport_ctx = None;
    self.tools_cache = [];
    self.connected = False;
}

async def _async_cleanup(state: _McpState) {
    session_ctx = state.session_ctx;
    if session_ctx is not None {
        try {
            await session_ctx.__aexit__(None, None, None);
        } except Exception as e {
            logger.debug(f"Session __aexit__ error: {e}");
        }
    }
    transport_ctx = state.transport_ctx;
    if transport_ctx is not None {
        try {
            await transport_ctx.__aexit__(None, None, None);
        } except Exception as e {
            logger.debug(f"Transport __aexit__ error: {e}");
        }
    }
}

impl McpClient.postinit -> None {
    self._id = str(uuid.uuid4());
}

glob _states: dict[str, _McpState] = {};

def _get_state(client: McpClient) -> _McpState {
    if client._id not in _states {
        _states[client._id] = _McpState();
    }
    return _states[client._id];
}

async def _do_connect(client: McpClient, transport_type: str) {
    import from mcp.client.session { ClientSession }
    import from datetime { timedelta }

    state = _get_state(client);
    (read_stream, write_stream) = await _open_transport(client, transport_type);

    session_ctx = ClientSession(
        read_stream,
        write_stream,
        read_timeout_seconds=timedelta(seconds=client.timeout)
    );
    state.session_ctx = session_ctx;
    session = await session_ctx.__aenter__();
    state.session = session;
    await session.initialize();

    tools_result = await session.list_tools();
    discovered: list[McpTool] = [];
    for t in tools_result.tools {
        raw_schema = t?.inputSchema;
        schema: dict[str, any] = raw_schema if isinstance(raw_schema, dict) else {};
        discovered.append(
            McpTool(
                name=str(getattr(t, "name", "")),
                description=str(getattr(t, "description", "") or ""),
                input_schema=schema,
                _client=client
            )
        );
    }
    state.tools_cache = discovered;
    state.connected = True;
    logger.info(
        f"[MCP] Connected via {transport_type} — "
        f"{len(state.tools_cache)} tool(s) discovered."
    );
}

async def _do_call_tool(
    client: McpClient, name: str, arguments: dict[str, any]
) -> str {
    import from mcp.client.session { ClientSession }

    state = _get_state(client);
    session = state.session;
    if not isinstance(session, ClientSession) {
        raise McpError(message="MCP session is not connected.");
    }
    logger.debug(f"[MCP] call_tool {name}({arguments})");
    result = await session.call_tool(name, arguments);
    parts: list[str] = [];
    content: any = result.content or [];
    for item in content {
        text = item?.text;
        parts.append(str(text) if text is not None else str(item));
    }
    return "\n".join(parts) if parts else "MCP tool returned no content.";
}

async def _open_transport(client: McpClient, transport_type: str) -> tuple[any, ...] {
    import from mcp.client.stdio { StdioServerParameters, stdio_client }
    import from mcp.client.sse { sse_client }
    import from mcp.client.streamable_http { streamablehttp_client }

    if transport_type == "stdio" {
        ctx = stdio_client(
            StdioServerParameters(
                command=client.command, args=client.args, env=client.env or None
            )
        );
    } elif transport_type == "sse" {
        ctx = sse_client(
            client.url, headers=client.headers or None, timeout=float(client.timeout)
        );
    } elif transport_type == "streamable-http" {
        ctx = streamablehttp_client(client.url, headers=client.headers or None);
    } else {
        raise McpError(
            message=f"Unknown transport: '{transport_type}'. "
            "Use 'stdio', 'sse', or 'streamable-http'."
        );
    }
    state = _get_state(client);
    state.transport_ctx = ctx;
    streams = await ctx.__aenter__();
    return (streams[0], streams[1]);
}

impl McpClient.connect -> None {
    state = _get_state(self);
    if state.connected {
        return;
    }
    try {
        import from mcp.client.session { ClientSession }
    } except ImportError {
        raise McpError(
            message="MCP support requires the 'mcp' package. "
            "Install it with: pip install byllm[mcp]"
        );
    }
    transport_type = self.transport;
    if transport_type == "auto" {
        if self.command {
            transport_type = "stdio";
        } elif self.url {
            transport_type = "streamable-http";
        } else {
            raise McpError(
                message="McpClient requires either 'command' (stdio) or 'url' (HTTP)."
            );
        }
    }
    state.start_loop();
    try {
        state.run_task(_do_connect(self, transport_type));
    } except McpError {
        state.stop();
        raise;
    } except Exception as e {
        state.stop();
        hint = "";
        if transport_type == "streamable-http" and self.transport == "auto" {
            hint = " If this is an SSE server, pass transport='sse' explicitly.";
        }
        raise McpError(message=f"Failed to connect to MCP server: {e}{hint}") from e;
    }
}

impl McpClient.get_tools(names: list[str] | None = None) -> list[McpTool] {
    state = _get_state(self);
    if not state.connected {
        self.connect();
    }
    if names is None {
        return list(state.tools_cache);
    }
    names_set = set(names);
    return [
        t
        for t in state.tools_cache
        if t.name in names_set
    ];
}

impl McpClient.call_tool(name: str, arguments: dict[str, any]) -> str {
    state = _get_state(self);
    if not state.connected {
        self.connect();
    }
    try {
        return state.run_text(_do_call_tool(self, name, arguments));
    } except McpError {
        raise;
    } except Exception as e {
        raise McpError(message=f"MCP tool '{name}' call failed: {e}") from e;
    }
}

impl McpClient.close -> None {
    state = _get_state(self);
    if not state.connected {
        return;
    }
    state.stop();
    _states.pop(self._id, None);
}

impl McpTool.__call__(**kwargs: any) -> str {
    try {
        return self._client.call_tool(self.name, kwargs);
    } except Exception as e {
        logger.exception("MCP tool execution failed");
        return f"Tool error: {e}";
    }
}

impl McpTool.get_name -> str {
    return self.name;
}

impl McpTool.get_json_schema -> dict[str, any] {
    return {
        "type": "function",
        "function": {
            "name": self.name,
            "description": self.description,
            "parameters": self.input_schema
        }
    };
}

impl McpTool.parse_arguments(args_json: dict[str, any]) -> dict[str, any] {
    return args_json;
}

impl McpTool.is_finish_tool -> bool {
    return False;
}
