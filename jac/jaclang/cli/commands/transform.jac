import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="py2jac",
    help="Convert Python code to Jac",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .py file"), ],
    examples=[("jac py2jac script.py", "Convert a Python file to Jac"), ],
    group="transform"
)
def py2jac(filename: str) -> int;

@registry.command(
    name="jac2py",
    help="Convert Jac code to Python",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2py myprogram.jac", "Convert a Jac file to Python"), ],
    group="transform"
)
def jac2py(filename: str) -> int;

@registry.command(
    name="jac2js",
    help="Convert Jac code to JavaScript",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2js myprogram.jac", "Convert a Jac file to JavaScript"), ],
    group="transform"
)
def jac2js(filename: str) -> int;

@registry.command(
    name="js",
    help="[Deprecated] Alias for 'jac2js'. Convert Jac code to JavaScript",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[
        ("jac js myprogram.jac", "Deprecated; prefer 'jac jac2js myprogram.jac'"),

    ],
    group="transform"
)
def js(filename: str) -> int;
