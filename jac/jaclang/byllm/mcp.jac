import asyncio;
import logging;
import threading;
import uuid;
import from jaclang.byllm.exceptions { McpError }

glob logger = logging.getLogger("byllm.mcp");

obj McpClient {
    has command: str = "",
        args: list[str] = [],
        env: dict[str, str] = {},
        url: str = "",
        headers: dict[str, str] = {},
        transport: str = "auto",
        timeout: int = 30,
        _id: str postinit;

    def postinit -> None;
    def connect -> None;
    def get_tools(names: list[str] | None = None) -> list;
    def call_tool(name: str, arguments: dict[str, any]) -> str;
    def close -> None;
}

obj McpTool {
    has name: str,
        description: str,
        input_schema: dict[str, any],
        _client: McpClient;

    def __call__(**kwargs: any) -> str;
    def get_name -> str;
    def get_json_schema -> dict[str, any];
    def parse_arguments(args_json: dict) -> dict;
    def is_finish_tool -> bool;
}
