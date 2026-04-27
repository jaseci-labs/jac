"""Implementation of MCP client and tool wrapper.

Architecture: MCP transports are stateful — they run background tasks
(stdio reader/writer, SSE listener) that must stay alive between
connect() and call_tool(). We run one persistent event loop in a
daemon thread per McpClient. Sync methods post coroutines to it
via asyncio.run_coroutine_threadsafe() and block on the result.

This will simplify when byllm adds native async support.
"""

# ─── Background event loop ──────────────────────────────────────────────────
"""Shared state for one McpClient's background loop + session."""
obj _McpState {
    has loop: object = None,
        thread: object = None,
        session: object = None,
        session_ctx: object = None,
        transport_ctx: object = None,
        tools_cache: list = [],
        connected: bool = False,
        _lock: object by postinit;

    def postinit -> None;
    def start_loop -> None;
    def run(coro: object) -> str;
    def stop -> None;
}

impl _McpState.postinit -> None {
    self._lock = threading.Lock();
}

impl _McpState.start_loop -> None {
    self.loop = asyncio.new_event_loop();
    self.thread = threading.Thread(target=self.loop.run_forever, daemon=True);
    self.thread.start();
}

impl _McpState.run(coro: object) -> str {
    with self._lock {
        future = asyncio.run_coroutine_threadsafe(coro, self.loop);
        return future.result(timeout=120);
    }
}

impl _McpState.stop -> None {
    # Clean shutdown: exit contexts before stopping loop to avoid killing MCP subprocess.
    if self.loop and self.loop.is_running() {
        try {
            self.run(_async_cleanup(self));
        } except Exception as e {
            logger.debug(f"MCP cleanup failed: {e}");
        }
        self.loop.call_soon_threadsafe(self.loop.stop);
    }
    if self.thread and self.thread.is_alive() {
        self.thread.join(timeout=5);
    }
    if self.loop and not self.loop.is_closed() {
        self.loop.close();
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
    if state.session_ctx is not None {
        try {
            await state.session_ctx.__aexit__(None, None, None);
        } except Exception as e {
            logger.debug(f"Session __aexit__ error: {e}");
        }
    }
    if state.transport_ctx is not None {
        try {
            await state.transport_ctx.__aexit__(None, None, None);
        } except Exception as e {
            logger.debug(f"Transport __aexit__ error: {e}");
        }
    }
}

impl McpClient.postinit -> None {
    self._id = str(uuid.uuid4());
}

glob _states: dict = {};

def _get_state(client: McpClient) -> _McpState {
    if client._id not in _states {
        _states[client._id] = _McpState();
    }
    return _states[client._id];
}

# ─── Async internals ────────────────────────────────────────────────────────
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
    state.session = await session_ctx.__aenter__();
    await state.session.initialize();

    tools_result = await state.session.list_tools();
    import from byllm.mcp { McpTool }
    state.tools_cache = [
        McpTool(
            name=t.name,
            description=t.description or "",
            input_schema=t?.inputSchema or {},
            _client=client
        ) for t in tools_result.tools
    ];
    state.connected = True;
    logger.info(
        f"[MCP] Connected via {transport_type} — "
        f"{len(state.tools_cache)} tool(s) discovered."
    );
}

async def _do_call_tool(
    client: McpClient, name: str, arguments: dict[str, Any]
) -> str {
    state = _get_state(client);
    logger.debug(f"[MCP] call_tool {name}({arguments})");
    result = await state.session.call_tool(name, arguments);
    parts: list[str] = [];
    for item in (result.content or []) {
        if hasattr(item, 'text') {
            parts.append(item.text);
        } else {
            parts.append(str(item));
        }
    }
    return "\n".join(parts) if parts else "MCP tool returned no content.";
}

async def _open_transport(client: McpClient, transport_type: str) -> tuple {
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

# ─── McpClient ──────────────────────────────────────────────────────────────
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
        state.run(_do_connect(self, transport_type));
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

impl McpClient.get_tools(names: list[str] | None = None) -> list {
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

impl McpClient.call_tool(name: str, arguments: dict[str, Any]) -> str {
    state = _get_state(self);
    if not state.connected {
        self.connect();
    }
    try {
        return state.run(_do_call_tool(self, name, arguments));
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

# ─── McpTool ────────────────────────────────────────────────────────────────
impl McpTool.__call__(**kwargs: Any) -> str {
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

impl McpTool.get_json_schema -> dict[str, Any] {
    return {
        "type": "function",
        "function": {
            "name": self.name,
            "description": self.description,
            "parameters": self.input_schema
        }
    };
}

impl McpTool.parse_arguments(args_json: dict) -> dict {
    return args_json;
}

impl McpTool.is_finish_tool -> bool {
    return False;
}
