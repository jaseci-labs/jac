import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import type from jaclang.project.config { JacConfig }
import from jaclang.comptime { name as ct_name }


comptime SPEC_CREATE: CommandSpec = CommandSpec(
         name="create",
         help="Create a new Jac project",
         tier="core",
         args=[
             Arg.create(
                 "name",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Project name (omit to initialize the current directory)"
             ),
             Arg.create(
                 "force",
                 typ=bool,
                 `default=False,
                 help="Overwrite existing jac.toml",
                 short="f"
             ),
             Arg.create(
                 "kind",
                 `default="",
                 help="Project or app kind to scaffold (cli, cli-native, service, web-app, ...)",
                 short="k"
             ),
             Arg.create(
                 "app",
                 `default="",
                 short="",
                 help="Scaffold an app of --kind inside the current project and register [apps.<app>] in its jac.toml"
             ),
             Arg.create(
                 "path",
                 `default="",
                 short="",
                 help="With --app: directory for the app, relative to the project root (default: the app name)"
             ),
             Arg.create(
                 "use",
                 `default="default",
                 help="Template: a published template (org/name or org/name@range), a template directory or .jab, or a variant name",
                 short="u"
             ),
             Arg.create(
                 "awesome",
                 typ=bool,
                 `default=False,
                 help="Scaffold the full jaclang.org site (landing, docs, leaderboard, socialize, wasm game) as your project"
             ),
             Arg.create(
                 "awetiny",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Scaffold Tiny JacYac (web, mobile, desktop, CLI, feed and scoring services) as your project"
             ),
             Arg.create(
                 "list",
                 typ=bool,
                 `default=False,
                 help="List available project kinds and named variants",
                 short="l"
             ),
             Arg.create(
                 "skip",
                 typ=bool,
                 `default=False,
                 help="Skip dependency installation (Python + npm); run 'jac install' later"
             ),
             Arg.create(
                 "style",
                 typ=str,
                 `default=None,
                 help="shadcn style preset (nova|vega|maia|lyra|mira|luma|rhea|sera)",
                 short=""
             ),
             Arg.create(
                 "baseColor",
                 typ=str,
                 `default=None,
                 help="shadcn base palette (neutral|stone|zinc|gray)",
                 short=""
             ),
             Arg.create(
                 "theme",
                 typ=str,
                 `default=None,
                 help="shadcn accent theme (e.g. rose, emerald)",
                 short=""
             ),
             Arg.create(
                 "font",
                 typ=str,
                 `default=None,
                 help="shadcn font family (e.g. inter, outfit)",
                 short=""
             ),
             Arg.create(
                 "radius",
                 typ=str,
                 `default=None,
                 help="shadcn border radius (none|small|medium|large)",
                 short=""
             ),
             Arg.create(
                 "menuAccent",
                 typ=str,
                 `default=None,
                 help="shadcn menu accent (subtle|bold)",
                 short=""
             ),
             Arg.create(
                 "menuColor",
                 typ=str,
                 `default=None,
                 help="shadcn menu color scheme",
                 short=""
             ),

         ],
         examples=[
             (
                 "jac create",
                 "Initialize a cli project in the current directory (name from cwd)"
             ),
             (
                 "jac create myapp --use acme/starter",
                 "Create a project from a published template"
             ),
             ("jac create myapp", "Create new myapp/ directory (cli kind)"),
             ("jac create myapp --kind service", "Scaffold a headless API service"),
             (
                 "jac create myapp --kind native-binary",
                 "Scaffold a natively-compiled binary"
             ),
             ("jac create myapp --kind web-app", "Scaffold a full-stack web app"),
             (
                 "jac create --app mobile --kind mobile",
                 "Add a mobile app to the current project as [apps.mobile]"
             ),
             (
                 "jac create mysite --awesome",
                 "Dump the entire jaclang.org site as your project"
             ),
             (
                 "jac create mysocial --awetiny",
                 "Create the Tiny JacYac social app workspace"
             ),
             ("jac create --force", "Reinitialize existing project"),
             (
                 "jac create --use ./my-template",
                 "Create from a local template directory"
             ),
             ("jac create --use ./starter.jab", "Create from a template package file"),
             ("jac create --list", "List available project kinds and named variants"),

         ],
         group="project",
         handler_name=ct_name(create)
     );

def create(
    name: str = "",
    force: bool = False,
    kind: str = "",
    app: str = "",
    path: str = "",
    use: str = "default",
    awesome: bool = False,
    awetiny: bool = False,
    `list: bool = False,
    `skip: bool = False,
    style: str | None = None,
    baseColor: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menuAccent: str | None = None,
    menuColor: str | None = None
) -> int;

comptime SPEC_INSTALL: CommandSpec = CommandSpec(
         name="install",
         help="Install project dependencies",
         args=[
             Arg.create(
                 "packages",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Jac package(s) to add (org/name or org/name@range); with --pypi, Python package(s)"
             ),
             Arg.create(
                 "pypi",
                 typ=bool,
                 `default=False,
                 short="",
                 help="The named packages (or --git repository) are Python packages for [dependencies.pypi] and .jac/venv"
             ),
             Arg.create(
                 "path",
                 `default="",
                 short="",
                 help="Add the Jac package in this local directory as a path dependency"
             ),
             Arg.create(
                 "rev",
                 `default="",
                 short="",
                 help="With --git: the branch, tag or commit to use"
             ),
             Arg.create(
                 "frozen",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Install exactly what jac.lock pins; fail if jac.lock is missing or out of date (for CI)"
             ),
             Arg.create(
                 "editable",
                 kind=ArgKind.APPEND,
                 `default=[],
                 help="Install the package at this path in editable mode; repeat for multiple packages",
                 short="e",
                 metavar="PATH"
             ),
             Arg.create(
                 "dev",
                 typ=bool,
                 `default=False,
                 help="Include dev dependencies, or record named package(s) as dev dependencies",
                 short="d"
             ),
             Arg.create(
                 "extras",
                 kind=ArgKind.MULTI_OPTION,
                 `default=[],
                 help="Optional dependency groups to install (e.g. data monitoring)",
                 short="x"
             ),
             Arg.create(
                 "no-save",
                 typ=bool,
                 `default=False,
                 help="Install named package(s) without recording them in jac.toml",
                 short=""
             ),
             Arg.create(
                 "git",
                 `default="",
                 help="Git repository URL of a Jac package to add (with --pypi, of a Python package)",
                 short="g"
             ),
             Arg.create(
                 "npm",
                 typ=bool,
                 `default=None,
                 help="Install npm package(s); with no names, install all npm deps from jac.toml. With --global, install standalone npm CLI tools runnable via 'jac x --global'. As --no-npm, skip npm dependencies during a full install"
             ),
             Arg.create(
                 "shadcn",
                 typ=bool,
                 `default=False,
                 help="Install shadcn UI component(s) from the bundled registry"
             ),
             Arg.create(
                 "verbose", typ=bool, `default=False, help="Verbose output", short="v"
             ),
             Arg.create(
                 "force-reinstall",
                 typ=bool,
                 `default=False,
                 help="Reinstall all packages even if they are already up-to-date",
                 short=""
             ),
             Arg.create(
                 "no-cache-dir",
                 typ=bool,
                 `default=False,
                 help="Disable the pip download cache",
                 short=""
             ),
             Arg.create(
                 "pre",
                 typ=bool,
                 `default=False,
                 help="Include pre-release and development versions",
                 short=""
             ),
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 help="Show what would be installed without actually installing anything",
                 short=""
             ),
             Arg.create(
                 "no-deps",
                 typ=bool,
                 `default=False,
                 help="Don't install package dependencies",
                 short=""
             ),
             Arg.create(
                 "quiet", typ=bool, `default=False, help="Suppress pip output", short=""
             ),
             Arg.create(
                 "prefer-binary",
                 typ=bool,
                 `default=False,
                 help="Prefer wheel files over source distributions",
                 short=""
             ),
             Arg.create(
                 "global",
                 typ=bool,
                 `default=False,
                 help="Install into the jac-owned global store shared by every project, not the project venv (Python: the global site; with --npm: global npm CLI tools)",
                 short="",
                 dest="install_global"
             ),
             Arg.create(
                 "scale",
                 typ=bool,
                 `default=False,
                 help="Materialize the deploy-time capability closure (adds deploy-only clients like kubernetes/docker) instead of just the runtime closure",
                 short=""
             ),
             Arg.create(
                 "plan",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Show the fully resolved dependency plan instead of installing (absorbs 'jac deps')"
             ),
             Arg.create(
                 "json",
                 typ=bool,
                 `default=False,
                 short="",
                 dest="as_json",
                 help="With --plan: emit the plan as JSON"
             ),

         ],
         examples=[
             ("jac install", "Resolve, lock and install every dependency in jac.toml"),
             ("jac install --frozen", "Install exactly what jac.lock pins (CI)"),
             ("jac install --plan", "Show the fully resolved dependency plan"),
             ("jac install jaseci/vecdb", "Add a Jac package from the registry"),
             (
                 'jac install "jaseci/vecdb@^2.1"',
                 "Add a Jac package with a version range"
             ),
             ("jac install --path ../util", "Add a local Jac package"),
             (
                 "jac install --git https://github.com/acme/kit --rev v1.2.0",
                 "Add a Jac package from git"
             ),
             (
                 "jac install --scale",
                 "Also install deploy-time capabilities (kubernetes/docker) for the operator machine"
             ),
             (
                 "jac install --pypi requests",
                 "Add a Python package to [dependencies.pypi]"
             ),
             (
                 'jac install --pypi "numpy>=1.24" pandas',
                 "Add Python packages with version constraints"
             ),
             ("jac install --pypi pytest --dev", "Add a Python dev dependency"),
             (
                 "jac install --pypi numpy --no-save",
                 "Install a Python package without recording it in jac.toml"
             ),
             (
                 "jac install --pypi --git https://github.com/user/plugin.git",
                 "Add a Python package from git"
             ),
             ("jac install --npm left-pad", "Add a client-side npm dependency"),
             ("jac install --shadcn button card", "Add shadcn UI components"),
             ("jac install -e .", "Install current package in editable mode"),
             (
                 "jac install -e /path/to/lib",
                 "Install a cloned library in editable mode"
             ),
             (
                 "jac install -e ./my-plugin -e ./my-lib",
                 "Install multiple packages in editable mode (space-separated or repeated -e)"
             ),
             ("jac install --dev", "Include dev dependencies"),
             (
                 "jac install --extras data monitoring",
                 "Include optional dependency groups"
             ),
             (
                 "jac install -e . --extras all",
                 "Editable install with all optional deps"
             ),
             ("jac install --force-reinstall", "Reinstall all packages from scratch"),
             ("jac install --pre", "Include pre-release versions"),
             (
                 "jac install --no-cache-dir",
                 "Install without using pip's download cache"
             ),
             (
                 "jac install --dry-run",
                 "Preview what would be installed without doing it"
             ),
             ("jac install --no-deps", "Install packages without their dependencies"),
             (
                 "jac install --prefer-binary",
                 "Prefer pre-built wheels over source builds"
             ),
             (
                 "jac install -e ./my-plugin --global",
                 "Install a plugin into the global site so it's importable from any project"
             ),

         ],
         group="project",
         handler_name=ct_name(install)
     );

def install(
    packages: list[str] = [],
    pypi: bool = False,
    path: str = "",
    rev: str = "",
    frozen: bool = False,
    editable: list[any] = [],
    dev: bool = False,
    extras: list[str] = [],
    no_save: bool = False,
    git: str = "",
    npm: bool | None = None,
    shadcn: bool = False,
    verbose: bool = False,
    force_reinstall: bool = False,
    no_cache_dir: bool = False,
    pre: bool = False,
    dry_run: bool = False,
    no_deps: bool = False,
    quiet: bool = False,
    prefer_binary: bool = False,
    install_global: bool = False,
    scale: bool = False,
    plan: bool = False,
    as_json: bool = False
) -> int;

comptime SPEC_REMOVE: CommandSpec = CommandSpec(
         name="remove",
         help="Remove a dependency from the project",
         args=[
             Arg.create(
                 "packages",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Jac packages (org/name) to remove; with --pypi, Python packages"
             ),
             Arg.create(
                 "pypi",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Remove Python package(s) from [dependencies.pypi]"
             ),
             Arg.create(
                 "dev",
                 typ=bool,
                 `default=False,
                 help="Remove from dev dependencies",
                 short="d"
             ),
             Arg.create(
                 "npm",
                 typ=bool,
                 `default=False,
                 help="Remove npm (client-side) dependency"
             ),
             Arg.create(
                 "shadcn",
                 typ=bool,
                 `default=False,
                 help="Remove shadcn UI component(s)"
             ),

         ],
         examples=[
             ("jac remove jaseci/vecdb", "Remove a Jac package"),
             ("jac remove --pypi requests", "Remove a Python package"),
             ("jac remove --pypi pytest --dev", "Remove a Python dev dependency"),
             ("jac remove --npm left-pad", "Remove a client-side npm dependency"),
             ("jac remove --shadcn button", "Remove shadcn UI components"),

         ],
         group="project",
         handler_name=ct_name(remove)
     );

def remove(
    packages: list[str] = [],
    pypi: bool = False,
    dev: bool = False,
    npm: bool = False,
    shadcn: bool = False
) -> int;

comptime SPEC_PUBLISH: CommandSpec = CommandSpec(
         name="publish",
         help="Publish this package (library or template) to the package index",
         args=[
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Build the package and run every publish gate (API diff, semver, checks) without uploading"
             ),
             Arg.create(
                 "yank",
                 `default="",
                 short="",
                 metavar="VERSION",
                 help="Open an index pull request that marks VERSION yanked (new resolutions skip it; locks keep it)"
             ),
             Arg.create(
                 "registry",
                 `default="",
                 short="",
                 help="Publish to a registry named under [registries] instead of the default index"
             ),
             Arg.create(
                 "output",
                 `default="",
                 short="o",
                 help="Also write the built package .jab into this directory"
             ),
             Arg.create(
                 "verify-index",
                 `default="",
                 short="",
                 metavar="DIR",
                 help="Index CI: verify the index checkout at DIR against --base (append-only lines, owners, uploads, API digest, semver)"
             ),
             Arg.create(
                 "base",
                 `default="",
                 short="",
                 help="With --verify-index: the git ref the pull request is based on"
             ),
             Arg.create(
                 "author",
                 `default="",
                 short="",
                 help="With --verify-index: the GitHub login that opened the pull request"
             ),
             Arg.create(
                 "mirror-out",
                 `default="",
                 short="",
                 help="With --verify-index: write the verified blobs to copy into the index blob store as JSON"
             ),

         ],
         examples=[
             (
                 "jac publish --dry-run",
                 "Build and check the package, show the API diff"
             ),
             ("jac publish", "Open the index pull request that publishes this version"),
             ("jac publish --yank 1.2.0", "Mark a published version yanked"),
             (
                 "jac publish --verify-index . --base origin/main --author octocat",
                 "Verify an index pull request (index repository CI)"
             ),

         ],
         group="project",
         handler_name=ct_name(publish)
     );

def publish(
    dry_run: bool = False,
    yank: str = "",
    registry: str = "",
    output: str = "",
    verify_index: str = "",
    base: str = "",
    author: str = "",
    mirror_out: str = ""
) -> int;

comptime SPEC_UPDATE: CommandSpec = CommandSpec(
         name="update",
         help="Update project dependencies to latest compatible versions",
         args=[
             Arg.create(
                 "packages",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Jac packages to re-resolve (all if empty); with --pypi, Python packages"
             ),
             Arg.create(
                 "pypi",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Update Python packages only"
             ),
             Arg.create(
                 "dev",
                 typ=bool,
                 `default=False,
                 help="Include dev dependencies",
                 short="d"
             ),
             Arg.create(
                 "verbose", typ=bool, `default=False, help="Verbose output", short="v"
             ),

         ],
         examples=[
             ("jac update", "Re-resolve every dependency within its range"),
             ("jac update jaseci/vecdb", "Re-resolve one Jac package"),
             ("jac update --pypi requests", "Update one Python package"),
             ("jac update --dev", "Also update dev dependencies"),

         ],
         group="project",
         handler_name=ct_name(update)
     );

def update(
    packages: list[str] = [],
    pypi: bool = False,
    dev: bool = False,
    verbose: bool = False
) -> int;

def deps(scale: bool = False, as_json: bool = False) -> int;

def script(name: str = "", list_scripts: bool = False) -> int;

comptime SPEC_CLEAN: CommandSpec = CommandSpec(
         name="clean",
         help="Clean project build artifacts",
         args=[
             Arg.create(
                 "all",
                 typ=bool,
                 `default=False,
                 help="Clean all .jac artifacts (data, cache, packages, client)",
                 short="a"
             ),
             Arg.create(
                 "data",
                 typ=bool,
                 `default=False,
                 help="Clean data directory (.jac/data)",
                 short="d"
             ),
             Arg.create(
                 "cache",
                 typ=bool,
                 `default=False,
                 help="Clean cache directory (.jac/cache)",
                 short="c"
             ),
             Arg.create(
                 "packages",
                 typ=bool,
                 `default=False,
                 help="Clean virtual environment (.jac/venv)",
                 short="p"
             ),
             Arg.create(
                 "force",
                 typ=bool,
                 `default=False,
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
         group="project",
         handler_name=ct_name(clean)
     );

def clean(
    all: bool = False,
    data: bool = False,
    cache: bool = False,
    packages: bool = False,
    force: bool = False
) -> int;


def bundle(
    output: str = "dist",
    target: str = "wheel",
    fat: bool = False,
    app: str = "",
    allow_drop_client: bool = False
) -> int;
