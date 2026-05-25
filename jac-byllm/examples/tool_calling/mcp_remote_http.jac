import from byllm.lib { McpClient }

glob msdocs = McpClient(url="https://learn.microsoft.com/api/mcp");

def ask_msdocs(question: str) -> str by llm(tools=[*msdocs.get_tools()]);

sem ask_msdocs = "Answer Microsoft technology questions using the Microsoft Learn MCP server.";

with entry {
    print(ask_msdocs("How do I create a Function App in Azure?"));
    msdocs.close();
}
