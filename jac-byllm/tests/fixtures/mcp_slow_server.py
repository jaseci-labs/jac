"""Tiny in-process stdio MCP server used to verify byllm.McpClient lets
concurrent call_tool requests run in parallel on the underlying
ClientSession (which multiplexes by JSON-RPC id). The single tool
sleeps for SLEEP_SEC; if N concurrent calls take ~N*SLEEP_SEC, byllm is
serializing them.
"""

import asyncio
import sys

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

SLEEP_SEC = 0.5

server: Server = Server("byllm-mcp-concurrency-probe")


@server.list_tools()
async def _list_tools() -> list[Tool]:
    return [
        Tool(
            name="slow",
            description="Sleeps for SLEEP_SEC then returns 'ok'.",
            inputSchema={"type": "object", "properties": {}},
        )
    ]


@server.call_tool()
async def _call_tool(name: str, arguments: dict) -> list[TextContent]:
    await asyncio.sleep(SLEEP_SEC)
    return [TextContent(type="text", text="ok")]


async def _main() -> None:
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        sys.exit(0)
