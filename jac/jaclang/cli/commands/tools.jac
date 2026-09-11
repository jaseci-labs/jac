import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_TOOL: CommandSpec = CommandSpec(
         name="tool",
         help="Run AST tools",
         args=[
             Arg.create(
                 "tool", kind=ArgKind.POSITIONAL, help="Name of the AST tool to run"
             ),
             Arg.create(
                 "args",
                 kind=ArgKind.REMAINDER,
                 `default=[],
                 help="Arguments for the tool"
             ),

         ],
         examples=[
             ("jac tool list_tools", "List all available AST tools"),
             ("jac tool <tool_name> [args...]", "Run a specific tool"),

         ],
         group="tools",
         handler_name=ct_name(tool)
     );

def tool(tool: str, args: list[str] = []) -> int;

comptime SPEC_DOT: CommandSpec = CommandSpec(
         name="dot",
         hidden=True,
         help="Generate graph visualization (DOT format)",
         args=[
             Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
             Arg.create("session", `default="", help="Session identifier", short="s"),
             Arg.create("initial", `default="", help="Initial node ID", short="i"),
             Arg.create(
                 "depth", typ=int, `default=-1, help="Max traversal depth", short="d"
             ),
             Arg.create(
                 "traverse",
                 typ=bool,
                 `default=False,
                 help="Enable traversal mode",
                 short="t"
             ),
             Arg.create(
                 "connection",
                 kind=ArgKind.MULTI_OPTION,
                 `default=[],
                 help="Connection filters",
                 short="c"
             ),
             Arg.create(
                 "bfs",
                 typ=bool,
                 `default=False,
                 help="Use breadth-first search",
                 short="b"
             ),
             Arg.create(
                 "edge_limit", typ=int, `default=512, help="Max edges", short="e"
             ),
             Arg.create(
                 "node_limit", typ=int, `default=512, help="Max nodes", short="n"
             ),
             Arg.create("saveto", `default="", help="Output file path", short="o"),
             Arg.create(
                 "to_screen",
                 typ=bool,
                 `default=False,
                 help="Print to stdout",
                 short="p"
             ),
             Arg.create("format", `default="dot", help="Output format", short="f"),

         ],
         examples=[
             ("jac dot myprogram.jac", "Generate DOT graph"),
             ("jac dot myprogram.jac --saveto graph.dot", "Save to file"),
             ("jac dot myprogram.jac --depth 3", "Limit traversal depth"),

         ],
         group="tools",
         handler_name=ct_name(dot)
     );

def dot(
    filename: str,
    session: str = "",
    initial: str = "",
    depth: int = -1,
    traverse: bool = False,
    connection: list[str] = [],
    bfs: bool = False,
    edge_limit: int = 512,
    node_limit: int = 512,
    saveto: str = "",
    to_screen: bool = False,
    format: str = "dot"
) -> int;

comptime SPEC_LSP: CommandSpec = CommandSpec(
         name="lsp",
         help="Start Jac language server",
         args=[],
         examples=[("jac lsp", "Start language server for IDE integration"), ],
         group="tools",
         handler_name=ct_name(lsp)
     );

def lsp -> int;

comptime SPEC_COMPLETIONS: CommandSpec = CommandSpec(
         name="completions",
         hidden=True,
         help="Generate shell completion script",
         args=[
             Arg.create(
                 "shell",
                 typ=str,
                 `default="bash",
                 help="Shell to generate completions for (bash, zsh, fish)",
                 short="s"
             ),
             Arg.create(
                 "install",
                 typ=bool,
                 `default=False,
                 help="Install completions to shell config file (~/.bashrc, ~/.zshrc, etc.)",
                 short="i"
             ),

         ],
         examples=[
             ("jac completions --install", "Install bash completions to ~/.bashrc"),
             (
                 "jac completions --shell zsh --install",
                 "Install zsh completions to ~/.zshrc"
             ),
             ("jac completions --shell bash", "Print bash completions to stdout"),

         ],
         group="tools",
         handler_name=ct_name(completions)
     );

def completions(shell: str = "bash", install: bool = False) -> int;
