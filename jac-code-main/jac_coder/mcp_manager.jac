"""MCP server registry for jac-coder.

Manages connections to external MCP servers so the agent can call their tools.
Server configs are stored in the Jac graph (McpRegistry node) and persisted
automatically by jaclang's TieredMemory (SQLite).

Supported transport types:
  stdio  — spawn a local subprocess (command + args)
  http   — streamable-http remote server (url)
  sse    — SSE remote server (url)
"""

import os;
import json;


"""Add or update an MCP server. Returns status dict."""
def mcp_add_server(name: str, config: dict) -> dict;

"""Disconnect an MCP server (closes connection, keeps config). Returns status dict."""
def mcp_disconnect_server(name: str) -> dict;

"""Reconnect a previously-disconnected MCP server. Returns status dict."""
def mcp_reconnect_server(name: str) -> dict;

"""Permanently delete a user-added MCP server. Built-in servers cannot be deleted."""
def mcp_delete_server(name: str) -> dict;

"""List all configured MCP servers with their tool counts."""
def mcp_list_servers() -> list;

"""Return all tools from all configured MCP servers as a flat list."""
def mcp_get_tools() -> list;

"""Call a specific tool on a specific MCP server."""
def mcp_call_tool(server_name: str, tool_name: str, arguments: dict) -> str;

"""Register a built-in server without checking connection.
Saves now and tries it on first real tool call.
"""
def mcp_register_builtin(name: str, config: dict) -> None;
