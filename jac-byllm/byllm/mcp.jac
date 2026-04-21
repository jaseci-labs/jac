"""MCP (Model Context Protocol) integration for byLLM.

Provides McpTool and McpClient for using remote MCP server tools
in by llm() calls, alongside local tools.
"""

import asyncio;
import logging;
import threading;
import uuid;
import from typing { Any }
import from byllm.exceptions { McpError }

glob logger = logging.getLogger("byllm.mcp");

"""MCP server connection manager."""
obj McpClient {
    has command: str = "",
        args: list[str] = [],
        env: dict[str, str] = {},
        url: str = "",
        headers: dict[str, str] = {},
        transport: str = "auto",
        timeout: int = 30,
        _id: str by postinit;

    def postinit -> None;
    def connect -> None;
    def get_tools(names: list[str] | None = None) -> list;
    def call_tool(name: str, arguments: dict[str, Any]) -> str;
    def close -> None;
}

"""MCP tool wrapper with the same interface as byllm's Tool."""
obj McpTool {
    has name: str,
        description: str,
        input_schema: dict[str, Any],
        _client: McpClient;

    def __call__(**kwargs: Any) -> str;
    def get_name -> str;
    def get_json_schema -> dict[str, Any];
    def parse_arguments(args_json: dict) -> dict;
    def is_finish_tool -> bool;
}
