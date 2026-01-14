"""Analysis commands: check, build, format, test, gen_parser.

Commands for analyzing, building, and testing Jac code.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Run type checker for specified .jac files."""
@registry.command(
    name="check",
    help="Type check Jac files",
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
            "warnonly",
            typ=bool,
            default=False,
            help="Treat errors as warnings",
            short="w"
        ),
        Arg.create(
            "ignore",
            typ=str,
            default="",
            help="Comma-separated list of files/folders to ignore"
        ),

    ],
    examples=[
        ("jac check myprogram.jac", "Check a single file"),
        ("jac check file1.jac file2.jac", "Check multiple files"),
        ("jac check myproject/", "Check all files in directory"),
        ("jac check myprogram.jac --warnonly", "Report but don't fail on errors"),
        ("jac check myproject/ --ignore fixtures", "Check excluding folders,files"),

    ],
    group="analysis"
)
def check(
    paths: list, print_errs: bool = True, warnonly: bool = False, ignore: str = ""
) -> int;

"""Build the specified .jac file."""
@registry.command(
    name="build",
    help="Compile Jac to .jir format",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"),
        Arg.create(
            "typecheck",
            typ=bool,
            default=False,
            help="Perform type checking",
            short="t"
        ),

    ],
    examples=[
        ("jac build myprogram.jac", "Build without type checking"),
        ("jac build myprogram.jac --typecheck", "Build with type checking"),

    ],
    group="analysis"
)
def build(filename: str, typecheck: bool = False) -> int;

"""Format .jac files with improved code style."""
@registry.command(
    name="format",
    help="Format Jac source code",
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
            "fix",
            typ=bool,
            default=False,
            help="Apply auto-linting corrections",
            short="f"
        ),

    ],
    examples=[
        ("jac format myfile.jac", "Format a single file"),
        ("jac format myproject/", "Format all files in directory"),
        ("jac format myfile.jac --to_screen", "Preview formatted output"),
        ("jac format myfile.jac --fix", "Format with auto-linting"),

    ],
    group="analysis"
)
def format(paths: list, to_screen: bool = False, fix: bool = False) -> int;

"""Run the test suite in the specified .jac file or directory."""
@registry.command(
    name="test",
    help="Run Jac test suite",
    args=[
        Arg.create(
            "filepath",
            kind=ArgKind.POSITIONAL,
            help="Path to test file or directory",
            default=""
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

    ],
    examples=[
        ("jac test", "Run all tests in current directory"),
        ("jac test mytest.jac", "Run tests in specific file"),
        ("jac test --test_name my_test", "Run only test_my_test"),
        ("jac test --xit --verbose", "Stop on first failure with verbose output"),

    ],
    group="analysis"
)
def test(
    filepath: str = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    verbose: bool = False
) -> int;

"""Generate static parser."""
@registry.command(
    name="gen_parser",
    help="Generate Jac parser (internal use)",
    args=[],
    examples=[("jac gen_parser", "Regenerate the Jac parser"), ],
    group="analysis"
)
def gen_parser -> int;
