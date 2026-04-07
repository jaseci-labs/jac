"""JacCoder public API."""

import os;
import sys;

import from datetime { datetime }
import from jac_coder.config {
    get_config,
    set_model as _set_model,
    get_model as _get_model
}
import from jac_coder.util.tool_output { tool_end }
import from jac_coder.permission { permission_engine }
import from jac_coder.util.sandbox { set_sandbox_root, set_browser_exec }
import from jac_coder.context { build_context, ContextConfig }
import from jac_coder.walkers { new_session, ensure_main_agent, _consume_llm_stream }
import from jac_coder.mcp_manager {
    mcp_add_server,
    mcp_disconnect_server,
    mcp_reconnect_server,
    mcp_delete_server,
    mcp_list_servers,
    mcp_get_tools,
    mcp_register_builtin
}
import from jac_coder.memory {
    find_or_create_memory,
    _init_memory,
    update_memory_from_session
}
import from jac_coder.nodes { Session, MainAgent }
import from jac_coder.tool.guarded { _set_chat_session, _clear_chat_session, _chat_contexts }
import from jac_coder.events {
    register_event_callback,
    clear_event_callbacks,
    reset_steps,
    start_turn,
    emit_turn_summary,
    emit_event,
    is_abort_requested,
    clear_abort
}


# Thread-safe session registry — graph root() is per-request in jac-cloud,
# so background threads can't find sessions via [root()-->]. This dict
# is module-level and accessible from any thread.
glob _session_registry: dict = {};

"""Initialize jac-coder."""
def initialize(mode: str = "web") -> None;

"""Create a new session."""
def create_session(directory: str, title: str = "", agent: str = "main") -> dict;

"""Send a message and get a response."""
def chat(
    session_id: str,
    message: str,
    directory: str = "",
    on_event: Any = None,
    mode: str = "full",
    agent_context: str = "",
    images: list = [],
    edit_mode: str = "auto"
) -> dict;

def list_sessions() -> list;

def get_session(session_id: str) -> dict;

def close_session(session_id: str) -> dict;

# --- Model management API ---
"""Switch the active LLM model."""
def api_set_model(model: str) -> dict;

"""Get current model info."""
def api_get_model() -> dict;

# --- MCP management API ---
"""Add or update an MCP server."""
def api_mcp_add(name: str, config: dict) -> dict;

"""Disconnect an MCP server (keeps config, stays in list)."""
def api_mcp_disconnect(name: str) -> dict;

"""Reconnect a previously-disconnected MCP server."""
def api_mcp_reconnect(name: str) -> dict;

"""Permanently delete a user-added MCP server."""
def api_mcp_delete(name: str) -> dict;

"""List all configured MCP servers."""
def api_mcp_list() -> list;

"""Append an abort note to a session's chat_history (called synchronously from stop handler)."""
def abort_session(session_id: str) -> None;
