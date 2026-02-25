"""CLI command registration for jac-mcp.

This module registers the `jac mcp` CLI command that starts the MCP server.
"""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg }
import from jaclang.jac0core.runtime { hookimpl }

glob registry = get_registry();

"""Register 'mcp' command at module level."""
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
            "inspect",
            typ=bool,
            default=False,
            help="Print inventory of resources, tools, and prompts then exit",
            short=""
        ),

    ],
    examples=[
        ("jac mcp", "Start MCP server with stdio transport (default)"),
        ("jac mcp --transport sse --port 3001", "Start with SSE transport"),
        ("jac mcp --inspect", "List available resources, tools, and prompts"),

    ],
    group="tools",
    source="jac-mcp"
)
def mcp_cmd(
    transport: str = "stdio",
    port: int = 3001,
    host: str = "127.0.0.1",
    inspect: bool = False
) -> int {
    return 0;
}

"""Jac CLI extensions for MCP server."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Register mcp command pre-hook.""";
        registry = get_registry();
        registry.extend_command(
            command_name="mcp", pre_hook=_handle_mcp_cmd, source="jac-mcp"
        );
    }
}

"""Pre-hook to handle mcp command."""
def _handle_mcp_cmd(ctx: object) -> None {
    transport = ctx.get_arg("transport", "stdio");
    port = ctx.get_arg("port", 3001);
    host = ctx.get_arg("host", "127.0.0.1");
    inspect_mode = ctx.get_arg("inspect", False);

    if inspect_mode {
        _print_inspect();
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
        return;
    }

    # Start the server
    import from jac_mcp.server { JacMcpServer }
    server = JacMcpServer(transport=transport, port=port, host=host);
    server.start();
    ctx.set_data("cancel_execution", True);
    ctx.set_data("cancel_return_code", 0);
}

"""Print inventory of available resources, tools, and prompts."""
def _print_inspect -> None {
    import from jac_mcp.resources { ResourceProvider }
    import from jac_mcp.tools { ToolProvider }
    import from jac_mcp.prompts { PromptProvider }
    import sys;

    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();

    tp = ToolProvider();
    tools = tp.list_tools();

    pp = PromptProvider();
    prompts = pp.list_prompts();

    w = sys.stdout.write;
    w("=== jac-mcp Inventory ===\n\n");

    w(f"Resources ({len(resources)}):\n");
    for r in resources {
        w(f"  {r['uri']:40s} {r['name']}\n");
    }

    w(f"\nTools ({len(tools)}):\n");
    for t in tools {
        w(f"  {t['name']:25s} {t['description']}\n");
    }

    w(f"\nPrompts ({len(prompts)}):\n");
    for p in prompts {
        w(f"  {p['name']:25s} {p['description']}\n");
    }
}
