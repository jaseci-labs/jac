"""Build command: compile a Jac project into a .jab whole-program artifact.

Commands for building and type-checking Jac projects.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Build a .jab whole-program artifact from a Jac project."""
@registry.command(
    name="build",
    help="Build a Jac project into a .jab artifact",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Path to .jac entry file; defaults to [project] entry-point from jac.toml"
        ),
        Arg.create(
            "profile",
            default="release",
            help="Build profile (dev or release)",
            short=""
        ),
        Arg.create(
            "out",
            default="",
            help="Output path; defaults to .jac/build/<profile>/<entry>.jab",
            short="o"
        ),
        Arg.create(
            "target",
            default="all",
            choices=["server", "client", "native", "all"],
            help="Which targets to build: server, client, native, or all",
            short=""
        ),
        Arg.create("no_typecheck", kind=ArgKind.FLAG, help="Skip type-checking gate"),
        Arg.create(
            "check_only", kind=ArgKind.FLAG, help="Type-check only, emit nothing"
        ),

    ],
    examples=[
        ("jac build", "Build the project (uses entry-point from jac.toml)"),
        ("jac build app.jac", "Build a specific entry file"),
        ("jac build --profile dev", "Build with dev profile"),
        ("jac build --no-typecheck app.jac", "Build without type-checking"),
        ("jac build --check-only app.jac", "Type-check only, emit nothing"),
        ("jac build --out dist/app.jab app.jac", "Build to a specific output path"),

    ],
    group="build"
)
def build(
    filename: str = "",
    profile: str = "release",
    out: str = "",
    target: str = "all",
    no_typecheck: bool = False,
    check_only: bool = False
) -> int;
