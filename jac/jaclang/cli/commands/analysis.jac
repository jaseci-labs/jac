"""Analysis commands: check, lint, format, test, gen_parser.

Commands for analyzing and testing Jac code.
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

    ],
    examples=[
        ("jac check myprogram.jac", "Check a single file"),
        ("jac check file1.jac file2.jac", "Check multiple files"),
        ("jac check myproject/", "Check all files in directory"),
        ("jac check myprogram.jac --warnonly", "Report but don't fail on errors"),
        ("jac check myproject/ --ignore fixtures", "Check excluding folders,files"),
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
    warnonly: bool = False,
    ignore: str = "",
    parse_only: bool = False,
    nowarn: bool = False
) -> int;

"""Lint .jac files and report violations."""
@registry.command(
    name="lint",
    help="Lint Jac files and report violations",
    args=[
        Arg.create(
            "paths", kind=ArgKind.MULTI, help="Paths to .jac files or directories"
        ),
        Arg.create(
            "fix", typ=bool, default=False, help="Auto-fix lint violations", short="f"
        ),
        Arg.create(
            "ignore",
            typ=str,
            default="",
            help="Comma-separated list of files/folders to ignore"
        ),

    ],
    examples=[
        ("jac lint myfile.jac", "Lint a single file"),
        ("jac lint myproject/", "Lint all files in directory"),
        ("jac lint myfile.jac --fix", "Auto-fix lint violations"),
        ("jac lint . --ignore fixtures", "Lint excluding folders"),

    ],
    group="analysis"
)
def lint(paths: list, fix: bool = False, ignore: str = "") -> int;

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

    ],
    examples=[
        ("jac format myfile.jac", "Format a single file"),
        ("jac format myproject/", "Format all files in directory"),
        ("jac format myfile.jac --to_screen", "Preview formatted output"),
        ("jac format . --lintfix", "Format and auto-fix lint violations"),
        ("jac format . --check", "Check formatting without modifying files"),

    ],
    group="analysis"
)
def format(
    paths: list, to_screen: bool = False, lintfix: bool = False, check: bool = False
) -> int;

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
        ("jac test --test_name my_test", "Run only test_my_test"),
        ("jac test --xit --verbose", "Stop on first failure with verbose output"),

    ],
    group="analysis"
)
def `test(
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

"""Extract grammar from the Jac parser and print in EBNF or Lark format."""
@registry.command(
    name="grammar",
    help="Extract and print the Jac grammar",
    args=[
        Arg.create(
            "lark",
            typ=bool,
            default=False,
            help="Output in Lark format instead of EBNF"
        ),
        Arg.create(
            "output",
            default="",
            help="Write output to file instead of stdout",
            short="o"
        ),

    ],
    examples=[
        ("jac grammar", "Print EBNF grammar to stdout"),
        ("jac grammar --lark", "Print Lark grammar to stdout"),
        ("jac grammar -o jac.ebnf", "Write EBNF grammar to file"),
        ("jac grammar --lark -o jac.lark", "Write Lark grammar to file"),

    ],
    group="analysis"
)
def grammar(lark: bool = False, output: str = "") -> int;
