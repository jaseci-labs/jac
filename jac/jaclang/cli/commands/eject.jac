"""Eject command: convert a Jac project to standalone Python + JavaScript.

Walks a Jac project, compiles every .jac source file to its Python and
JavaScript equivalents, copies static assets, and writes a runnable project
folder containing zero .jac files. The ejected backend still imports from
the installed `jaclang` runtime library at execution time, but no Jac source
or compilation step is required to run it.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Eject a Jac project to standalone Python + JavaScript."""
@registry.command(
    name="eject",
    help="Eject a Jac project to standalone Python + JavaScript",
    args=[
        Arg.create(
            "source",
            kind=ArgKind.POSITIONAL,
            default=".",
            help="Project directory to eject (default: current directory)"
        ),
        Arg.create(
            "output",
            default="",
            help="Output directory (default: <name>-ejected next to source)",
            short="o"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Overwrite output directory if it already exists",
            short="f"
        ),

    ],
    examples=[
        ("jac eject", "Eject the current project to ./<name>-ejected/"),
        ("jac eject . -o /tmp/myapp", "Eject current project to /tmp/myapp"),
        ("jac eject myapp --force", "Eject myapp/, overwriting existing output"),

    ],
    group="project"
)
def eject(source: str = ".", output: str = "", force: bool = False) -> int;
