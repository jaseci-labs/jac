"""Implementation of the mcp_call agent tool."""


impl mcp_call(server_name: str, tool_name: str, arguments_json: str = "{}") -> str {
    tool_status("mcp_call", f"{server_name}.{tool_name}");

    if not server_name or not tool_name {
        tool_end("-> error: missing server_name or tool_name", error=True);
        return "Error: server_name and tool_name are required.";
    }

    import json as _json;
    try {
        args: dict = _json.loads(arguments_json) if arguments_json else {};
    } except Exception as e {
        tool_end(f"-> error: invalid JSON — {e}", error=True);
        return f"Error: arguments_json is invalid JSON — {e}";
    }

    try {
        result: str = str(mcp_call_tool(server_name, tool_name, args));
    } except Exception as e {
        tool_end(f"-> error: {e}", error=True);
        return f"Error: MCP call failed — {e}";
    }

    preview = result[:80].replace("\n", " ");
    tool_end(f"-> {preview}");

    (output, _) = truncate_output(result);
    return output;
}
