"""Project commands: create, install, add, remove, script.

Commands for managing Jac projects and dependencies.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Initialize a new Jac project."""
@registry.command(
    name="create",
    help="Create a new Jac project",
    args=[
        Arg.create(
            "name",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Project name (uses current directory if empty)"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Overwrite existing jac.toml",
            short="f"
        ),

    ],
    examples=[
        ("jac create", "Create project in current directory"),
        ("jac create myapp", "Create new myapp/ directory"),
        ("jac create --force", "Reinitialize existing project"),

    ],
    group="project"
)
def create(name: str = "", force: bool = False) -> int;

"""Install all dependencies from jac.toml."""
@registry.command(
    name="install",
    help="Install project dependencies",
    args=[
        Arg.create(
            "dev", typ=bool, default=False, help="Include dev dependencies", short="d"
        ),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),

    ],
    examples=[
        ("jac install", "Install all dependencies"),
        ("jac install --dev", "Include dev dependencies"),
        ("jac install --verbose", "Show detailed progress"),

    ],
    group="project"
)
def install(dev: bool = False, verbose: bool = False) -> int;

"""Add dependencies to the project."""
@registry.command(
    name="add",
    help="Add a dependency to the project",
    args=[
        Arg.create(
            "packages", kind=ArgKind.MULTI, default=[], help="Package specifications"
        ),
        Arg.create(
            "dev", typ=bool, default=False, help="Add as dev dependency", short="d"
        ),
        Arg.create("git", default="", help="Git repository URL", short="g"),
        Arg.create("cl", typ=bool, default=False, help="Add as client-side dependency"),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),

    ],
    examples=[
        ("jac add requests", "Add a package"),
        ('jac add "numpy>=1.24" pandas', "Add multiple packages with version"),
        ("jac add pytest --dev", "Add dev dependency"),
        ("jac add --git https://github.com/user/plugin.git", "Add from git"),

    ],
    group="project"
)
def add(
    packages: list = [],
    dev: bool = False,
    git: str = "",
    cl: bool = False,
    verbose: bool = False
) -> int;

"""Remove dependencies from the project."""
@registry.command(
    name="remove",
    help="Remove a dependency from the project",
    args=[
        Arg.create(
            "packages", kind=ArgKind.MULTI, default=[], help="Packages to remove"
        ),
        Arg.create(
            "dev",
            typ=bool,
            default=False,
            help="Remove from dev dependencies",
            short="d"
        ),
        Arg.create("cl", typ=bool, default=False, help="Remove client-side dependency"),

    ],
    examples=[
        ("jac remove requests", "Remove a package"),
        ("jac remove pytest --dev", "Remove dev dependency"),

    ],
    group="project"
)
def remove(packages: list = [], dev: bool = False, cl: bool = False) -> int;

"""Run custom scripts defined in jac.toml."""
@registry.command(
    name="script",
    help="Run project scripts",
    args=[
        Arg.create(
            "name", kind=ArgKind.POSITIONAL, default="", help="Script name to run"
        ),
        Arg.create(
            "list_scripts",
            typ=bool,
            default=False,
            help="List available scripts",
            short="l"
        ),

    ],
    examples=[
        ("jac script --list", "List available scripts"),
        ("jac script build", "Run the 'build' script"),

    ],
    group="project"
)
def script(name: str = "", list_scripts: bool = False) -> int;
