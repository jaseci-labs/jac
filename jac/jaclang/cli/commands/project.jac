import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="create",
    help="Create a new Jac project",
    tier="core",
    args=[
        Arg.create(
            "name",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Project name (omit to initialize the current directory)"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Overwrite existing jac.toml",
            short="f"
        ),
        Arg.create(
            "kind",
            default="",
            help="Project kind to scaffold (cli, cli-native, service, web-app, ...)",
            short="k"
        ),
        Arg.create(
            "use",
            default="default",
            help="Custom template: file path or URL to a .jacpack (or a variant name)",
            short="u"
        ),
        Arg.create(
            "list_jacpacks",
            typ=bool,
            default=False,
            help="List available project kinds and templates",
            short="l"
        ),

    ],
    examples=[
        (
            "jac create",
            "Initialize a cli project in the current directory (name from cwd)"
        ),
        ("jac create myapp", "Create new myapp/ directory (cli kind)"),
        ("jac create myapp --kind service", "Scaffold a headless API service"),
        (
            "jac create myapp --kind native-binary",
            "Scaffold a natively-compiled binary"
        ),
        ("jac create myapp --kind web-app", "Scaffold a full-stack web app"),
        ("jac create --force", "Reinitialize existing project"),
        ("jac create --use ./my.jacpack", "Create from local .jacpack file"),
        ("jac create --use https://example.com/t.jacpack", "Create from URL"),
        ("jac create --list_jacpacks", "List available project kinds and templates"),

    ],
    group="project"
)
def create(
    name: str = "",
    force: bool = False,
    kind: str = "",
    use: str = "default",
    list_jacpacks: bool = False
) -> int;

@registry.command(
    name="install",
    help="Install project dependencies, or 'jac install <pkg>' to add a package to the project venv",
    args=[
        Arg.create(
            "packages",
            kind=ArgKind.MULTI,
            default=[],
            help="Package(s) to install into the project's venv (.jac/venv)"
        ),
        Arg.create(
            "editable",
            kind=ArgKind.APPEND,
            default=[],
            help="Install the package at this path in editable mode; repeat for multiple packages",
            short="e",
            metavar="PATH"
        ),
        Arg.create(
            "dev", typ=bool, default=False, help="Include dev dependencies", short="d"
        ),
        Arg.create(
            "extras",
            kind=ArgKind.MULTI,
            default=[],
            help="Optional dependency groups to install (e.g. data monitoring)",
            short="x"
        ),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),
        Arg.create(
            "force-reinstall",
            typ=bool,
            default=False,
            help="Reinstall all packages even if they are already up-to-date",
            short=""
        ),
        Arg.create(
            "no-cache-dir",
            typ=bool,
            default=False,
            help="Disable the pip download cache",
            short=""
        ),
        Arg.create(
            "pre",
            typ=bool,
            default=False,
            help="Include pre-release and development versions",
            short=""
        ),
        Arg.create(
            "dry-run",
            typ=bool,
            default=False,
            help="Show what would be installed without actually installing anything",
            short=""
        ),
        Arg.create(
            "no-deps",
            typ=bool,
            default=False,
            help="Don't install package dependencies",
            short=""
        ),
        Arg.create(
            "quiet", typ=bool, default=False, help="Suppress pip output", short=""
        ),
        Arg.create(
            "prefer-binary",
            typ=bool,
            default=False,
            help="Prefer wheel files over source distributions",
            short=""
        ),
        Arg.create(
            "global",
            typ=bool,
            default=False,
            help="Install into the jac-owned global site (importable from any project), not the project venv",
            short="",
            dest="install_global"
        ),
        Arg.create(
            "scale",
            typ=bool,
            default=False,
            help="Materialize the deploy-time capability closure (adds deploy-only clients like kubernetes/docker) instead of just the runtime closure",
            short=""
        ),

    ],
    examples=[
        ("jac install", "Install all dependencies from jac.toml"),
        (
            "jac install --scale",
            "Also install deploy-time capabilities (kubernetes/docker) for the operator machine"
        ),
        ("jac install numpy", "Install numpy into the project venv"),
        (
            "jac install numpy pandas scipy",
            "Install multiple packages into the project venv"
        ),
        ("jac install -e .", "Install current package in editable mode"),
        ("jac install -e /path/to/lib", "Install a cloned library in editable mode"),
        (
            "jac install -e ./my-plugin -e ./my-lib",
            "Install multiple packages in editable mode (space-separated or repeated -e)"
        ),
        ("jac install --dev", "Include dev dependencies"),
        ("jac install --extras data monitoring", "Include optional dependency groups"),
        ("jac install -e . --extras all", "Editable install with all optional deps"),
        ("jac install --force-reinstall", "Reinstall all packages from scratch"),
        ("jac install --pre", "Include pre-release versions"),
        ("jac install --no-cache-dir", "Install without using pip's download cache"),
        ("jac install --dry-run", "Preview what would be installed without doing it"),
        ("jac install --no-deps", "Install packages without their dependencies"),
        ("jac install --prefer-binary", "Prefer pre-built wheels over source builds"),
        (
            "jac install -e ./my-plugin --global",
            "Install a plugin into the global site so it's importable from any project"
        ),

    ],
    group="project"
)
def install(
    packages: list = [],
    editable: list = [],
    dev: bool = False,
    extras: list = [],
    verbose: bool = False,
    force_reinstall: bool = False,
    no_cache_dir: bool = False,
    pre: bool = False,
    dry_run: bool = False,
    no_deps: bool = False,
    quiet: bool = False,
    prefer_binary: bool = False,
    install_global: bool = False,
    scale: bool = False
) -> int;

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

@registry.command(
    name="bundle",
    help="Build a pure-Python .whl (PyPI) or npm .tgz (npmjs) from jac.toml; upload separately",
    args=[
        Arg.create(
            "output",
            default="dist",
            help="Output directory for the built artifact",
            short="o"
        ),
        Arg.create(
            "target",
            default="wheel",
            help="Build target: 'wheel' (pure-Python PyPI wheel, .jac transpiled to .py), 'npm' (npmjs), 'all', or 'npm-runtime'",
            short="t"
        ),

    ],
    examples=[
        ("jac bundle", "Build a pure-Python wheel into dist/ (.jac transpiled to .py)"),
        ("jac bundle --target npm", "Build an npm .tgz into dist/"),
        ("jac bundle -o /tmp/wheels", "Build to custom output directory"),

    ],
    group="project"
)
def bundle(output: str = "dist", target: str = "wheel") -> int;
