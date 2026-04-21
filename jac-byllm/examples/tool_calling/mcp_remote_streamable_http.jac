import from byllm.lib { McpClient }

glob jac_mcp = McpClient(
         url="https://jac-mcp.jaseci.org/mcp/",
         transport="streamable-http",
         headers={"Authorization": "Bearer YOUR_TOKEN"}
     );

def ask_jac_docs(question: str) -> str by llm(tools=[*jac_mcp.get_tools()]);

sem ask_jac_docs = "Answer Jac language questions using the hosted Jac MCP server.";

with entry {
    print(ask_jac_docs("What is the difference between obj and class in Jac?"));
    jac_mcp.close();
}
