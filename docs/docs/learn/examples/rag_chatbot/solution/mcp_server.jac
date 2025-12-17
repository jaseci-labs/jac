import os;
import from tools { RagEngine, WebSearch }
import from mcp.server.fastmcp.tools { Tool }
import from mcp.server.fastmcp { FastMCP }
import typing;

glob rag_engine: RagEngine = RagEngine() , web_search: WebSearch = WebSearch() , mcp = FastMCP(
    name="RAG-MCP", port=8899
);

def resolve_hints(fn: typing.Callable) -> typing.Callable {
    fn.__annotations__ = typing.get_type_hints(fn, include_extras=True);
    return fn;
}

@mcp.tool(name="search_docs")
@resolve_hints
async def tool_search_docs(query: str) -> str {
    return rag_engine.search(query);
}

@mcp.tool(name="search_web")
@resolve_hints
async def tool_search_web(query: str) -> str {
    web_search_results = web_search.search(query);
    if not web_search_results {
        return "Mention No results found for the web search";
    }
    return web_search_results;
}

with entry {
    mcp.run("streamable-http");
}
