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
            help="Project name (defaults to 'jactastic' with incrementing number if exists)"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Overwrite existing jac.toml",
            short="f"
        ),
        Arg.create(
            "use",
            default="default",
            help="Jacpack template: name, file path, or URL",
            short="u"
        ),
        Arg.create(
            "list_jacpacks",
            typ=bool,
            default=False,
            help="List available jacpack templates",
            short="l"
        ),

    ],
    examples=[
        (
            "jac create",
            "Create new jactastic/ directory (or jactastic1/, jactastic2/, etc.)"
        ),
        ("jac create myapp", "Create new myapp/ directory"),
        ("jac create --force", "Reinitialize existing project"),
        ("jac create myapp --use client", "Create with client jacpack template"),
        ("jac create --use ./my.jacpack", "Create from local .jacpack file"),
        ("jac create --use https://example.com/t.jacpack", "Create from URL"),
        ("jac create --list-jacpacks", "List available jacpack templates"),

    ],
    group="project"
)
def create(
    name: str = "",
    force: bool = False,
    use: str = "default",
    list_jacpacks: bool = False
) -> int;

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
    packages: list = [], dev: bool = False, git: str = "", verbose: bool = False
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

    ],
    examples=[
        ("jac remove requests", "Remove a package"),
        ("jac remove pytest --dev", "Remove dev dependency"),

    ],
    group="project"
)
def remove(packages: list = [], dev: bool = False) -> int;

"""Update project dependencies to latest compatible versions."""
@registry.command(
    name="update",
    help="Update project dependencies to latest compatible versions",
    args=[
        Arg.create(
            "packages",
            kind=ArgKind.MULTI,
            default=[],
            help="Packages to update (all if empty)"
        ),
        Arg.create(
            "dev", typ=bool, default=False, help="Include dev dependencies", short="d"
        ),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),

    ],
    examples=[
        ("jac update", "Update all dependencies to latest compatible versions"),
        ("jac update requests", "Update a specific package"),
        ("jac update --dev", "Also update dev dependencies"),

    ],
    group="project"
)
def update(packages: list = [], dev: bool = False, verbose: bool = False) -> int;

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

"""Clean project build artifacts."""
@registry.command(
    name="clean",
    help="Clean project build artifacts",
    args=[
        Arg.create(
            "all",
            typ=bool,
            default=False,
            help="Clean all .jac artifacts (data, cache, packages, client)",
            short="a"
        ),
        Arg.create(
            "data",
            typ=bool,
            default=False,
            help="Clean data directory (.jac/data)",
            short="d"
        ),
        Arg.create(
            "cache",
            typ=bool,
            default=False,
            help="Clean cache directory (.jac/cache)",
            short="c"
        ),
        Arg.create(
            "packages",
            typ=bool,
            default=False,
            help="Clean virtual environment (.jac/venv)",
            short="p"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Force clean without confirmation",
            short="f"
        ),

    ],
    examples=[
        ("jac clean", "Clean data directory (default)"),
        ("jac clean --all", "Clean all .jac artifacts"),
        ("jac clean --cache", "Clean only cache directory"),
        ("jac clean --data --cache", "Clean data and cache directories"),

    ],
    group="project"
)
def clean(
    all: bool = False,
    data: bool = False,
    cache: bool = False,
    packages: bool = False,
    force: bool = False
) -> int;

"""Bundle a template directory into a distributable .jacpack file."""
@registry.command(
    name="jacpack",
    help="Manage project templates (.jacpack files)",
    args=[
        Arg.create(
            "action", kind=ArgKind.POSITIONAL, default="", help="Action: pack, list"
        ),
        Arg.create(
            "path",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Template directory path (for pack) or .jacpack path (for info)"
        ),
        Arg.create(
            "output",
            default="",
            help="Output file path for bundled template",
            short="o"
        ),

    ],
    examples=[
        (
            "jac jacpack pack ./my-template -o my-template.jacpack",
            "Bundle a template directory"
        ),
        ("jac jacpack list", "List available templates"),

    ],
    group="project"
)
def jacpack(action: str = "", path: str = "", output: str = "") -> int;
