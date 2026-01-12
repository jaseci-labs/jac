"""Execution commands: run, enter, serve, debug.

Commands for running and debugging Jac programs.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Run the specified .jac, .jir, or .py file."""
@registry.command(
    name="run",
    help="Run a Jac program",
    args=[
        Arg.create(
            "filename", kind=ArgKind.POSITIONAL, help="Path to .jac, .jir, or .py file"
        ),
        Arg.create(
            "session", default="", help="Session ID for persistent state", short="s"
        ),
        Arg.create(
            "main", typ=bool, default=True, help="Treat module as __main__", short="m"
        ),
        Arg.create(
            "cache", typ=bool, default=True, help="Enable compilation cache", short="c"
        ),

    ],
    examples=[
        ("jac run hello.jac", "Run a simple program"),
        ("jac run app.jac --session myapp", "Run with persistent session"),
        ("jac run app.jac --no-cache", "Run without caching"),

    ],
    group="execution"
)
def run(filename: str, session: str = "", main: bool = True, cache: bool = True) -> int;

"""Run the specified entrypoint function in the given .jac file."""
@registry.command(
    name="enter",
    help="Run a specific entrypoint in a Jac program",
    args=[
        Arg.create(
            "filename", kind=ArgKind.POSITIONAL, help="Path to .jac or .jir file"
        ),
        Arg.create(
            "entrypoint", kind=ArgKind.POSITIONAL, help="Function/walker to invoke"
        ),
        Arg.create("args", kind=ArgKind.REMAINDER, help="Arguments for entrypoint"),
        Arg.create("session", default="", help="Session ID", short="s"),
        Arg.create("main", typ=bool, default=True, help="Treat as __main__", short="m"),
        Arg.create("root", default="", help="Root executor ID", short="r"),
        Arg.create("node", default="", help="Starting node ID", short="n"),

    ],
    examples=[
        ("jac enter app.jac my_walker arg1 arg2", "Run walker with args"),
        ("jac enter app.jac process --node data_node", "Run with specific node"),

    ],
    group="execution"
)
def enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    session: str = "",
    main: bool = True,
    <>root: str = "",
    <>node: str = ""
) -> int;

"""Start REST API server."""
@registry.command(
    name="start",
    help="Start REST API server for a Jac program",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create("session", default="", help="Session identifier", short="s"),
        Arg.create("port", typ=int, default=8000, help="Server port", short="p"),
        Arg.create("main", typ=bool, default=True, help="Treat as __main__", short="m"),
        Arg.create(
            "faux",
            typ=bool,
            default=False,
            help="Print docs only (no server)",
            short="f"
        ),

    ],
    examples=[
        ("jac start app.jac", "Start server on default port"),
        ("jac start app.jac --port 3000", "Start server on port 3000"),
        ("jac start app.jac --faux", "Generate API docs without starting"),

    ],
    group="execution"
)
def start(
    filename: str,
    session: str = "",
    port: int = 8000,
    main: bool = True,
    faux: bool = False
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

    ],
    examples=[("jac debug myprogram.jac", "Debug a program"), ],
    group="execution"
)
def debug(filename: str, main: bool = True, cache: bool = False) -> int;
