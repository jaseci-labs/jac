import from jac_coder.mcp_manager { mcp_call_tool }
import from jac_coder.util.tool_output { tool_status, tool_end, truncate_output }


"""Call a tool provided by a connected MCP server.

Use this when the user's context includes available MCP tools.
Check the 'Available MCP tools' section in your context first,
then call the appropriate tool with the correct server_name and tool_name.

Arguments:
  server_name    — the MCP server name (from Available MCP tools list)
  tool_name      — the tool to call (from Available MCP tools list)
  arguments_json — JSON string of arguments matching the tool's input schema.
                   Use \"{}\" if the tool takes no arguments.
                   Example: \"{\\\"code\\\": \\\"glob x: int = 1;\\\"}\" """
def mcp_call(server_name: str, tool_name: str, arguments_json: str = "{}") -> str;
