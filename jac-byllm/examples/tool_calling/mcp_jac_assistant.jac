import from byllm.lib { McpClient }

glob jac_mcp = McpClient(command="jac", args=["mcp"]);

def cite(source: str) -> str {
    return f"[source: {source}]";
}

sem cite = "Append a citation marker to the answer.";

def ask_about_jac(question: str) -> str by llm(tools=[cite, *jac_mcp.get_tools()]);

sem ask_about_jac = "Answer Jac language questions using MCP tools, then cite the source.";

def validate_snippet(code: str) -> str by llm(
    tools=[*jac_mcp.get_tools(names=["validate_jac"])]
);

sem validate_snippet = "Validate a Jac snippet and report the compiler result.";

with entry {
    print(ask_about_jac("How do I declare an async function in Jac?"));
    print(validate_snippet("def greet(name: str) -> str { return f\"Hi, {name}!\"; }"));
    jac_mcp.close();
}
