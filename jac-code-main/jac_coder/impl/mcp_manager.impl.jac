"""MCP server registry implementation.

One persistent asyncio event loop runs in a background thread (mcp-manager).
Each MCP server gets one long-lived connection — stdio subprocess or HTTP
session — opened on first use and kept alive across all tool calls.

On failure the session is evicted and the next call reconnects automatically
(one retry).  Servers are cleanly disconnected when removed.
"""

import os;
import asyncio;
import sys;
import threading;
import from contextlib { AsyncExitStack }
import from mcp { ClientSession }
import from mcp.client.stdio { stdio_client, StdioServerParameters }
import from mcp.client.streamable_http { streamablehttp_client }
import from mcp.client.sse { sse_client }

# Cached update info for jac-mcp (populated by background thread on startup).
glob _jac_mcp_update_info: dict = {};

# Persistent manager loop — one background thread, all MCP sessions live here.
glob _mgr_loop: Any = None;
glob _mgr_thread: Any = None;
glob _mgr_lock: Any = threading.Lock();
glob _sessions: dict = {};     # name -> ClientSession (open inside _mgr_loop)
glob _exit_stacks: dict = {};  # name -> AsyncExitStack (keeps transports alive)
glob _tools_cache: dict = {};  # {"tools": [...], "ts": float} — cached tool list
glob _TOOLS_CACHE_TTL: int = 30;  # seconds before tool list is re-fetched
glob _builtin_names: set = set();  # names registered via mcp_register_builtin
glob _disconnected_names: set = set();  # names intentionally disconnected by user


"""Background thread: check PyPI for latest jac-mcp version (3s timeout, fails silently)."""
def _check_jac_mcp_version() -> None {
    try {
        import json;
        import from urllib.request { urlopen, Request };
        import from importlib.metadata { version };
        current: str = version("jac-mcp");
        req = Request(
            "https://pypi.org/pypi/jac-mcp/json",
            headers={"User-Agent": "jac-coder/update-check"}
        );
        with urlopen(req, timeout=3) as resp {
            data: dict = json.loads(resp.read().decode());
            latest: str = data["info"]["version"];
            _jac_mcp_update_info["current"] = current;
            _jac_mcp_update_info["latest"] = latest;
            _jac_mcp_update_info["update_available"] = latest != current;
        }
    } except Exception { }
}


# ---------------------------------------------------------------------------
# Graph-based config persistence
# ---------------------------------------------------------------------------

"""Find or create the McpRegistry node attached to root."""
def _get_registry() -> Any {
    import from jac_coder.nodes { McpRegistry };
    for edge_anchor in list(root().__jac__.edges) {
        try {
            target_anchor = edge_anchor.target;
            target_anchor.populate();
            if isinstance(target_anchor.archetype, McpRegistry) {
                return target_anchor.archetype;
            }
        } except Exception { }
    }
    save(root());
    reg = McpRegistry();
    root() ++> reg;
    commit();
    return reg;
}

"""Load all server configs from the persistent registry node."""
def _load_configs() -> dict {
    return dict(_get_registry().servers);
}

"""Persist the full server config dict back to the registry node."""
def _save_configs(configs: dict) -> None {
    reg = _get_registry();
    reg.servers = configs;
    save(reg);
    commit();
}


# ---------------------------------------------------------------------------
# Tool / result helpers
# ---------------------------------------------------------------------------

"""Build a tool descriptor dict from a server name and MCP tool object."""
def _tool_dict(server: str, t: Any) -> dict {
    return {
        "server": server,
        "name": t.name,
        "description": t.description or "",
        "inputSchema": t.inputSchema if hasattr(t, "inputSchema") else {}
    };
}

"""Extract plain text from an MCP tool result, joining multiple content items."""
def _extract_text(result: Any) -> str {
    texts = [item.text for item in result.content if hasattr(item, "text")];
    return "\n".join(texts) if texts else "ok";
}


# ---------------------------------------------------------------------------
# Persistent manager loop
# ---------------------------------------------------------------------------

"""Return the shared asyncio event loop, starting the background thread if needed."""
def _get_manager_loop() -> Any {
    global _mgr_loop, _mgr_thread;
    with _mgr_lock {
        if _mgr_loop is None or _mgr_thread is None or not _mgr_thread.is_alive() {
            _mgr_loop = asyncio.new_event_loop();
            _mgr_thread = threading.Thread(
                target=_mgr_loop.run_forever,
                daemon=True,
                name="mcp-manager"
            );
            _mgr_thread.start();
        }
    }
    return _mgr_loop;
}

"""Submit a coroutine to the persistent manager loop and block until it completes."""
def _submit(coro: Any) -> Any {
    loop = _get_manager_loop();
    future = asyncio.run_coroutine_threadsafe(coro, loop);
    return future.result(timeout=60);
}


# ---------------------------------------------------------------------------
# Connection lifecycle (async — run inside manager loop via _submit)
# ---------------------------------------------------------------------------

"""Open a persistent connection for *name* using the right transport and store session + exit stack."""
async def _open_connection(name: str, config: dict) -> None {
    transport = config.get("type", "stdio");
    stack = AsyncExitStack();
    try {
        if transport == "stdio" {
            cmd_list = config.get("command", []);
            if not cmd_list {
                raise ValueError("no command configured for stdio server");
            }
            env = {**os.environ, **config.get("env", {})};
            params = StdioServerParameters(command=cmd_list[0], args=cmd_list[1:], env=env);
            (read, write) = await stack.enter_async_context(stdio_client(params));
        } elif transport == "http" {
            url = config.get("url", "");
            if not url {
                raise ValueError("no url configured for http server");
            }
            headers = config.get("headers", {});
            (read, write, _) = await stack.enter_async_context(
                streamablehttp_client(url, headers=headers)
            );
        } elif transport == "sse" {
            url = config.get("url", "");
            if not url {
                raise ValueError("no url configured for sse server");
            }
            headers = config.get("headers", {});
            (read, write) = await stack.enter_async_context(
                sse_client(url, headers=headers)
            );
        } else {
            raise ValueError(f"unknown transport '{transport}'");
        }
        session = await stack.enter_async_context(ClientSession(read, write));
        await session.initialize();
        _sessions[name] = session;
        _exit_stacks[name] = stack;
    } except Exception {
        await stack.aclose();
        raise;
    }
}

"""Close and evict the session for *name* — no-op if not connected."""
async def _close_connection(name: str) -> None {
    stack = _exit_stacks.pop(name, None);
    _sessions.pop(name, None);
    if stack {
        try {
            await stack.aclose();
        } except Exception { }
    }
}

"""Return the cached session for *name*, opening a fresh connection if not yet connected."""
async def _ensure_session(name: str, config: dict) -> Any {
    if name not in _sessions {
        await _open_connection(name, config);
    }
    return _sessions[name];
}


# ---------------------------------------------------------------------------
# Async MCP operations — with one automatic reconnect on failure
# ---------------------------------------------------------------------------

"""List all tools exposed by *name*, reconnecting once if the session is stale."""
async def _async_list_tools(name: str, config: dict) -> list {
    for attempt in range(2) {
        try {
            session = await _ensure_session(name, config);
            result = await session.list_tools();
            return [_tool_dict(name, t) for t in result.tools];
        } except Exception {
            if attempt == 0 {
                await _close_connection(name);
            } else {
                raise;
            }
        }
    }
}

"""Call *tool_name* on *name* with *arguments*, reconnecting once if the session is stale."""
async def _async_call_tool(name: str, config: dict, tool_name: str, arguments: dict) -> str {
    for attempt in range(2) {
        try {
            session = await _ensure_session(name, config);
            result = await session.call_tool(tool_name, arguments);
            return _extract_text(result);
        } except Exception {
            if attempt == 0 {
                await _close_connection(name);
            } else {
                raise;
            }
        }
    }
}


# ---------------------------------------------------------------------------
# Public API implementations
# ---------------------------------------------------------------------------

"""Validate config, open a persistent connection, and save the server to the registry."""
impl mcp_add_server(name: str, config: dict) -> dict {
    if not name or not name.strip() {
        return {"error": "name is required"};
    }
    transport = config.get("type", "");
    if transport not in ("stdio", "http", "sse") {
        return {"error": "type must be 'stdio', 'http', or 'sse'"};
    }
    if transport == "stdio" and not config.get("command") {
        return {"error": "command is required for stdio servers"};
    }
    if transport in ("http", "sse") and not config.get("url") {
        return {"error": "url is required for http/sse servers"};
    }

    # Drop any stale connection before establishing the new one.
    _submit(_close_connection(name));

    try {
        tools = _submit(_async_list_tools(name, config));
    } except Exception as e {
        return {"error": f"Failed to connect to '{name}': {e}"};
    }
    configs = _load_configs();
    configs[name] = config;
    _save_configs(configs);
    _tools_cache.clear();  # Invalidate cache — new server added
    return {
        "status": "connected",
        "name": name,
        "tool_count": len(tools),
        "tools": [t["name"] for t in tools]
    };
}


"""Close the connection and remove the server from the registry."""
impl mcp_disconnect_server(name: str) -> dict {
    # Disconnect only — close the active connection but keep the config.
    # This applies to ALL servers (builtin and user-added) so they stay
    # visible in the list and can be reconnected.
    global _disconnected_names;
    configs = _load_configs();
    if name not in configs {
        return {"error": f"Server '{name}' not found"};
    }
    _disconnected_names.add(name);
    _submit(_close_connection(name));
    _tools_cache.clear();
    return {"status": "disconnected", "name": name};
}


"""Reconnect a previously-disconnected MCP server."""
impl mcp_reconnect_server(name: str) -> dict {
    global _disconnected_names;
    configs = _load_configs();
    if name not in configs {
        return {"error": f"Server '{name}' not found"};
    }
    _disconnected_names.discard(name);
    # Close any stale connection first, then reconnect via list_tools.
    # Iterate configs to get a typed config value (subscript on untyped dict
    # produces Unknown in the Jac type checker — the for pattern is used
    # consistently throughout this file).
    _submit(_close_connection(name));
    _tools_cache.clear();
    for (n, config) in configs.items() {
        if n == name {
            try {
                tools = _submit(_async_list_tools(n, config));
                return {"status": "connected", "name": name};
            } except Exception as e {
                _disconnected_names.add(name);
                return {"error": f"Failed to reconnect '{name}': {e}"};
            }
        }
    }
    return {"error": f"Server '{name}' not found"};
}


impl mcp_delete_server(name: str) -> dict {
    # Permanently remove a user-added server from the registry.
    # Built-in servers cannot be deleted.
    if name in _builtin_names {
        return {"error": f"Built-in server '{name}' cannot be deleted"};
    }
    configs = _load_configs();
    if name not in configs {
        return {"error": f"Server '{name}' not found"};
    }
    _submit(_close_connection(name));
    configs.pop(name);
    _save_configs(configs);
    _tools_cache.clear();
    return {"status": "deleted", "name": name};
}


"""Return all registered servers with their connection status and tool counts."""
impl mcp_list_servers() -> list {
    configs = _load_configs();
    result: list = [];
    for (name, config) in configs.items() {
        entry: dict = {
            "name": name,
            "type": config.get("type", ""),
            "builtin": config.get("builtin", False),
            "update_available": name == "jac-mcp" and _jac_mcp_update_info.get("update_available", False),
            "latest_version": _jac_mcp_update_info.get("latest", "") if name == "jac-mcp" else ""
        };
        # Skip auto-connect for servers the user intentionally disconnected
        if name in _disconnected_names {
            entry["status"] = "disconnected";
            entry["tool_count"] = 0;
            entry["tools"] = [];
        } else {
            try {
                tools = _submit(_async_list_tools(name, config));
                entry["status"] = "connected";
                entry["tool_count"] = len(tools);
                entry["tools"] = [t["name"] for t in tools];
            } except Exception as e {
                entry["status"] = "error";
                entry["error"] = str(e);
                entry["tool_count"] = 0;
                entry["tools"] = [];
            }
        }
        result.append(entry);
    }
    return result;
}


"""Save a built-in server to the registry without a connectivity check."""
impl mcp_register_builtin(name: str, config: dict) -> None {
    global _builtin_names;
    _builtin_names.add(name);
    configs = _load_configs();
    # Always update builtin config — the binary path can change between installs
    # (e.g. pipx venv vs workspace venv). Stale paths cause connection errors.
    config["builtin"] = True;
    configs[name] = config;
    _save_configs(configs);
    if name == "jac-mcp" {
        threading.Thread(target=_check_jac_mcp_version, daemon=True).start();
    }
}


"""Return a flat list of all tools from all registered servers (cached for 30s)."""
impl mcp_get_tools() -> list {
    import time;
    now = time.time();
    if _tools_cache and (now - _tools_cache.get("ts", 0)) < _TOOLS_CACHE_TTL {
        return _tools_cache["tools"];
    }

    configs = _load_configs();
    all_tools: list = [];
    for (name, config) in configs.items() {
        try {
            all_tools.extend(_submit(_async_list_tools(name, config)));
        } except Exception as e {
            sys.stderr.write(f"[mcp] get_tools({name}): {e}\n");
        }
    }

    _tools_cache["tools"] = all_tools;
    _tools_cache["ts"] = now;
    return all_tools;
}


"""Call a specific tool on a specific server and return the result as text."""
impl mcp_call_tool(server_name: str, tool_name: str, arguments: dict) -> str {
    configs = _load_configs();
    config = configs.get(server_name);
    if not config {
        return f"Error: MCP server '{server_name}' not configured. Use mcp.add to add it.";
    }
    return _submit(_async_call_tool(server_name, config, tool_name, arguments));
}
