"""Transform commands: py2jac, jac2py, js.

Commands for converting code between Jac, Python, and JavaScript.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Convert Python to Jac."""
@registry.command(
    name="py2jac",
    help="Convert Python code to Jac",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .py file"), ],
    examples=[("jac py2jac script.py", "Convert a Python file to Jac"), ],
    group="transform"
)
def py2jac(filename: str) -> int;

"""Convert Jac to Python."""
@registry.command(
    name="jac2py",
    help="Convert Jac code to Python",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2py myprogram.jac", "Convert a Jac file to Python"), ],
    group="transform"
)
def jac2py(filename: str) -> int;

"""Convert Jac to JavaScript."""
@registry.command(
    name="js",
    help="Convert Jac code to JavaScript",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac js myprogram.jac", "Convert a Jac file to JavaScript"), ],
    group="transform"
)
def js(filename: str) -> int;
