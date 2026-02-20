"""Execution commands: run, enter, serve, debug.

Commands for running and debugging Jac programs.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Run the specified .jac or .py file."""
@registry.command(
    name="run",
    help="Run a Jac program",
    args=[
        Arg.create(
            "filename", kind=ArgKind.POSITIONAL, help="Path to .jac or .py file"
        ),
        Arg.create(
            "main", typ=bool, default=True, help="Treat module as __main__", short="m"
        ),
        Arg.create(
            "cache", typ=bool, default=True, help="Enable compilation cache", short="c"
        ),
        Arg.create(
            "profile",
            default="",
            short="",
            help="Configuration profile to load (e.g. prod, staging)"
        ),
        Arg.create(
            "args", kind=ArgKind.REMAINDER, help="Arguments passed to the script"
        ),

    ],
    examples=[
        ("jac run hello.jac", "Run a simple program"),
        ("jac run --no-cache app.jac", "Run without caching"),
        ("jac run --profile prod app.jac", "Run with production profile"),
        ("jac run script.jac arg1 arg2", "Run with script arguments"),

    ],
    group="execution"
)
def run(filename: str, main: bool = True, cache: bool = True, args: list = []) -> int;

"""Run the specified entrypoint function in the given .jac file."""
@registry.command(
    name="enter",
    help="Run a specific entrypoint in a Jac program",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create(
            "entrypoint", kind=ArgKind.POSITIONAL, help="Function/walker to invoke"
        ),
        Arg.create("args", kind=ArgKind.REMAINDER, help="Arguments for entrypoint"),
        Arg.create("main", typ=bool, default=True, help="Treat as __main__", short="m"),
        Arg.create("root", default="", help="Root executor ID", short="r"),
        Arg.create("node", default="", help="Starting node ID", short="n"),
        Arg.create(
            "profile",
            default="",
            short="",
            help="Configuration profile to load (e.g. prod, staging)"
        ),

    ],
    examples=[
        ("jac enter app.jac my_walker arg1 arg2", "Run walker with args"),
        ("jac enter --node data_node app.jac process", "Run with specific node"),

    ],
    group="execution"
)
def enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    main: bool = True,
    `root: str = "",
    nd: str = ""
) -> int;

"""Start REST API server."""
@registry.command(
    name="start",
    help="Start REST API server for a Jac program",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            default="main.jac",
            help="Path to .jac file (default: main.jac)"
        ),
        Arg.create("port", typ=int, default=8000, help="Server port", short="p"),
        Arg.create("main", typ=bool, default=True, help="Treat as __main__", short="m"),
        Arg.create(
            "faux",
            typ=bool,
            default=False,
            help="Print docs only (no server)",
            short="f"
        ),
        Arg.create(
            "dev",
            typ=bool,
            default=False,
            help="Enable HMR (Hot Module Replacement) mode",
            short="d"
        ),
        Arg.create(
            "api_port",
            typ=int,
            default=0,
            help="Separate API port for HMR mode (0=same as port)"
        ),
        Arg.create(
            "no_client",
            typ=bool,
            default=False,
            help="Skip client bundling/serving (API only)"
        ),
        Arg.create(
            "profile",
            default="",
            short="",
            help="Configuration profile to load (e.g. prod, staging)"
        ),

    ],
    examples=[
        ("jac start", "Start server with default main.jac"),
        ("jac start app.jac", "Start server with specific file"),
        ("jac start --port 3000", "Start main.jac on port 3000"),
        ("jac start app.jac --faux", "Generate API docs without starting"),
        ("jac start --dev", "Start with hot module replacement"),
        ("jac start app.jac --dev --no-client", "HMR mode without client bundling"),
        ("jac start --profile prod", "Start with production profile"),

    ],
    group="execution"
)
def start(
    filename: str,
    port: int = 8000,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False
) -> int;

"""Debug a Jac program using Python debugger."""
@registry.command(
    name="debug",
    help="Debug a Jac program with Python debugger",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create("main", typ=bool, default=True, help="Treat as __main__", short="m"),
        Arg.create(
            "cache", typ=bool, default=False, help="Use cached compilation", short="c"
        ),
        Arg.create(
            "profile",
            default="",
            short="",
            help="Configuration profile to load (e.g. prod, staging)"
        ),

    ],
    examples=[("jac debug myprogram.jac", "Debug a program"), ],
    group="execution"
)
def debug(filename: str, main: bool = True, cache: bool = False) -> int;
