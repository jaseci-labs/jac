"""Tool commands: tool, dot, lsp.

Commands for development tools and utilities.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Run the specified AST tool with optional arguments."""
@registry.command(
    name="tool",
    help="Run AST tools",
    args=[
        Arg.create("tool", kind=ArgKind.POSITIONAL, help="Name of the AST tool to run"),
        Arg.create(
            "args", kind=ArgKind.REMAINDER, default=[], help="Arguments for the tool"
        ),

    ],
    examples=[
        ("jac tool list_tools", "List all available AST tools"),
        ("jac tool <tool_name> [args...]", "Run a specific tool"),

    ],
    group="tools"
)
def tool(tool: str, args: list = []) -> int;

"""Generate graph visualization."""
@registry.command(
    name="dot",
    help="Generate graph visualization (DOT format)",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create("session", default="", help="Session identifier", short="s"),
        Arg.create("initial", default="", help="Initial node ID", short="i"),
        Arg.create("depth", typ=int, default=-1, help="Max traversal depth", short="d"),
        Arg.create(
            "traverse",
            typ=bool,
            default=False,
            help="Enable traversal mode",
            short="t"
        ),
        Arg.create(
            "connection",
            kind=ArgKind.MULTI,
            default=[],
            help="Connection filters",
            short="c"
        ),
        Arg.create(
            "bfs", typ=bool, default=False, help="Use breadth-first search", short="b"
        ),
        Arg.create("edge_limit", typ=int, default=512, help="Max edges", short="e"),
        Arg.create("node_limit", typ=int, default=512, help="Max nodes", short="n"),
        Arg.create("saveto", default="", help="Output file path", short="o"),
        Arg.create(
            "to_screen", typ=bool, default=False, help="Print to stdout", short="p"
        ),
        Arg.create("format", default="dot", help="Output format", short="f"),

    ],
    examples=[
        ("jac dot myprogram.jac", "Generate DOT graph"),
        ("jac dot myprogram.jac --saveto graph.dot", "Save to file"),
        ("jac dot myprogram.jac --depth 3", "Limit traversal depth"),

    ],
    group="tools"
)
def dot(
    filename: str,
    session: str = "",
    initial: str = "",
    depth: int = -1,
    traverse: bool = False,
    connection: list = [],
    bfs: bool = False,
    edge_limit: int = 512,
    node_limit: int = 512,
    saveto: str = "",
    to_screen: bool = False,
    format: str = "dot"
) -> int;

"""Run Jac Language Server Protocol."""
@registry.command(
    name="lsp",
    help="Start Jac language server",
    args=[],
    examples=[("jac lsp", "Start language server for IDE integration"), ],
    group="tools"
)
def lsp -> int;
