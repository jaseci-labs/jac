import from jaclang.cli.command { Arg }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="mcp",
    help="Start the MCP (Model Context Protocol) server for AI-assisted Jac development",
    args=[
        Arg.create(
            "transport",
            typ=str,
            default="stdio",
            help="Transport protocol: stdio, sse, or streamable-http",
            choices=["stdio", "sse", "streamable-http"]
        ),
        Arg.create(
            "port",
            typ=int,
            default=3001,
            help="Port for SSE/HTTP transports (default: 3001)"
        ),
        Arg.create(
            "host",
            typ=str,
            default="127.0.0.1",
            help="Bind address for SSE/HTTP transports (default: 127.0.0.1)",
            short=""
        ),
        Arg.create(
            "mode",
            typ=str,
            default="",
            help="Tool/prompt exposure mode: lite, standard, or full (default: full)",
            choices=["lite", "standard", "full", ""],
            short=""
        ),
        Arg.create(
            "inspect",
            typ=bool,
            default=False,
            help="Print inventory of resources, tools, and prompts then exit",
            short=""
        )
    ],
    examples=[
        ("jac mcp", "Start MCP server with stdio transport (default)"),
        (
            "jac mcp --transport streamable-http --port 3001",
            "Start with HTTP transport"
        ),
        ("jac mcp --mode lite", "Start with lite mode for smaller models"),
        ("jac mcp --inspect", "List available resources, tools, and prompts")
    ],
    group="tools"
)
def mcp_cmd(
    transport: str = "stdio",
    port: int = 3001,
    host: str = "127.0.0.1",
    mode: str = "",
    inspect: bool = False
) -> int;

def _print_mcp_inventory -> None;
