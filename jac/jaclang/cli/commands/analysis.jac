import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="check",
    help="Type check Jac files",
    tier="core",
    args=[
        Arg.create(
            "paths", kind=ArgKind.MULTI, help="Paths to .jac files or directories"
        ),
        Arg.create(
            "print_errs",
            typ=bool,
            default=True,
            help="Print detailed error messages",
            short="e"
        ),
        Arg.create(
            "ignore",
            kind=ArgKind.MULTI,
            default=[],
            help="Directories or files to ignore (space separated)"
        ),
        Arg.create(
            "disable-error-code",
            kind=ArgKind.MULTI,
            default=[],
            help="Diagnostic codes or lint kebab aliases to suppress (same as [check].suppress in jac.toml; e.g. E1030 no-print)"
        ),
        Arg.create(
            "parse_only",
            typ=bool,
            default=False,
            help="Only check syntax (skip type checking)",
            short="p"
        ),
        Arg.create(
            "nowarn",
            typ=bool,
            default=False,
            help="Suppress warning output (warnings are still counted)"
        ),
        Arg.create(
            "lint",
            dest="lint_only",
            typ=bool,
            default=False,
            short="",
            help="Report lint violations only (absorbs 'jac lint')"
        ),
        Arg.create(
            "fix",
            typ=bool,
            default=False,
            short="",
            help="With --lint: auto-fix violations"
        ),
        Arg.create(
            "native-census",
            typ=bool,
            default=False,
            short="",
            help="Compile with codegen and report per-module native outcome (native / demoted / server) ranked by reason (needs the native toolchain)"
        ),

    ],
    examples=[
        ("jac check myprogram.jac", "Check a single file"),
        ("jac check . --native-census", "Rank modules by native compile outcome"),
        ("jac check . --lint", "Report lint violations only"),
        ("jac check . --lint --fix", "Auto-fix lint violations"),
        ("jac check file1.jac file2.jac", "Check multiple files"),
        ("jac check myproject/", "Check all files in directory"),
        ("jac check . --ignore jac scale test", "Check excluding directories"),
        (
            "jac check myprogram.jac --disable-error-code E1030 W2001",
            "Check while suppressing selected diagnostics"
        ),
        (
            "jac check myprogram.jac --parse-only",
            "Only check syntax, skip type checking"
        ),
        ("jac check myprogram.jac --nowarn", "Check without warnings"),

    ],
    group="analysis"
)
def check(
    paths: list,
    print_errs: bool = True,
    ignore: (list | None) = None,
    disable_error_code: (list | None) = None,
    parse_only: bool = False,
    nowarn: bool = False,
    lint_only: bool = False,
    fix: bool = False,
    native_census: bool = False
) -> int;

def lint(paths: list, fix: bool = False, ignore: (list | None) = None) -> int;

@registry.command(
    name="fmt",
    help="Format Jac source code",
    tier="core",
    args=[
        Arg.create(
            "paths", kind=ArgKind.MULTI, help="Paths to .jac files or directories"
        ),
        Arg.create(
            "to_screen",
            typ=bool,
            default=False,
            help="Print to stdout instead of writing",
            short="s"
        ),
        Arg.create(
            "lintfix",
            typ=bool,
            default=False,
            help="Also apply auto-lint fixes in the same pass",
            short="l"
        ),
        Arg.create(
            "check",
            typ=bool,
            default=False,
            help="Check if files are formatted without modifying them (exit 1 if unformatted)",
            short="c"
        ),
        Arg.create(
            "cache",
            typ=bool,
            default=False,
            help="Skip files already known to be formatted (content + config + version keyed)",
            short="C"
        ),

    ],
    examples=[
        ("jac fmt myfile.jac", "Format a single file"),
        ("jac fmt myproject/", "Format all files in directory"),
        ("jac fmt myfile.jac --to_screen", "Preview formatted output"),
        ("jac fmt . --lintfix", "Format and auto-fix lint violations"),
        ("jac fmt . --check", "Check formatting without modifying files"),

    ],
    group="analysis"
)
def format(
    paths: list,
    to_screen: bool = False,
    lintfix: bool = False,
    check: bool = False,
    cache: bool = False,
    cache_anchor: str = "",
    path_map: dict | None = None,
    cache_stats: dict | None = None
) -> int;

@registry.command(
    name="precommit",
    help="Run fmt (--lintfix) + check using jac.toml lint settings; installable as a git hook",
    hidden=True,
    args=[
        Arg.create(
            "paths",
            kind=ArgKind.MULTI,
            default=[],
            help="Paths to .jac files or directories (default: project root)"
        ),
        Arg.create(
            "staged", typ=bool, default=False, help="Only process git-staged .jac files"
        ),
        Arg.create(
            "verify",
            typ=bool,
            default=False,
            help="Verify only: do not rewrite files (exit 1 if unformatted)",
            short="v"
        ),
        Arg.create(
            "install",
            typ=bool,
            default=False,
            help="Install git pre-commit + commit-msg hooks"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="With --install: replace an existing foreign hook (a backup is kept)"
        ),

    ],
    examples=[
        ("jac precommit", "Format (lintfix) and check the whole project"),
        ("jac precommit --staged", "Run on staged '.jac' files only"),
        ("jac precommit --install", "Install the pre-commit + commit-msg hooks"),
        (
            "jac precommit --install --force",
            "Replace existing hooks (kept as .bak backups)"
        ),

    ],
    group="analysis"
)
def precommit(
    paths: (list | None) = None,
    staged: bool = False,
    verify: bool = False,
    install: bool = False,
    force: bool = False,
    cache_stats: dict | None = None
) -> int;

@registry.command(
    name="test",
    help="Run Jac test suite",
    tier="core",
    args=[
        Arg.create(
            "paths",
            kind=ArgKind.MULTI,
            help="Paths to test files or directories",
            default=[]
        ),
        Arg.create(
            "test_name",
            default="",
            help="Run specific test (without test_ prefix)",
            short="t"
        ),
        Arg.create(
            "filter", default="", help="Filter test files (Unix patterns)", short="f"
        ),
        Arg.create(
            "xit", typ=bool, default=False, help="Stop on first failure", short="x"
        ),
        Arg.create(
            "maxfail", typ=int, default=None, help="Stop after N failures", short="m"
        ),
        Arg.create("directory", default="", help="Test directory", short="d"),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),
        Arg.create(
            "ignore",
            default="",
            help="Path to skip during collection (pytest --ignore)"
        ),
        Arg.create(
            "profile",
            default="",
            short="",
            help="Configuration profile to load (e.g. prod, staging)"
        ),

    ],
    examples=[
        ("jac test", "Run all tests in current directory"),
        ("jac test mytest.jac", "Run tests in specific file"),
        ("jac test a.jac b.jac", "Run tests in several files"),
        ("jac test --test_name my_test", "Run only test_my_test"),
        ("jac test --xit --verbose", "Stop on first failure with verbose output"),

    ],
    group="analysis"
)
def `test(
    paths: list = [],
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    verbose: bool = False,
    ignore: str = ""
) -> int;

@registry.command(
    name="gen_parser",
    hidden=True,
    help="Generate Jac parser (internal use)",
    args=[],
    examples=[("jac gen_parser", "Regenerate the Jac parser"), ],
    group="analysis"
)
def gen_parser -> int;

def grammar(output: str = "", strict: bool = False) -> int;
