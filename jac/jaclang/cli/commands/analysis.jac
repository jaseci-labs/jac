import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_EXPLAIN: CommandSpec = CommandSpec(
         name="explain",
         help="Explain what the compiler inferred: memory (ownership, drops), placement (demotions), ir (optimized LLVM IR)",
         args=[
             Arg.create(
                 "topic",
                 kind=ArgKind.POSITIONAL,
                 choices=["memory", "placement", "ir"],
                 help="memory: inferred ownership states, receiver modes, raises effects and move sites; placement: every element's codespace with the diagnostics that decided it; ir: write the optimized .ll and a symbol map"
             ),
             Arg.create(
                 "filename", kind=ArgKind.POSITIONAL, help="The .jac file to explain"
             ),
             Arg.create(
                 "memory",
                 `default="",
                 choices=["managed", "rc", "nogc"],
                 short="",
                 help="memory: compile under this profile instead of the project's [memory] profile"
             ),
             Arg.create(
                 "output",
                 `default="",
                 help="ir: where to write the .ll (defaults to <file>.ll beside the source)",
                 short="o"
             ),

         ],
         examples=[
             (
                 "jac explain memory app.jac",
                 "Inferred ownership, receiver modes, raises effects, moves"
             ),
             (
                 "jac explain placement app.jac",
                 "Every demotion and the diagnostics that caused it"
             ),
             ("jac explain ir app.jac", "Write app.ll and print the symbol map")
         ],
         group="analysis",
         handler_name=ct_name(explain)
     ),
     SPEC_CHECK: CommandSpec = CommandSpec(
         name="check",
         help="Type check Jac files",
         tier="core",
         args=[
             Arg.create(
                 "paths",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Paths to .jac files or directories (none = the workspace gate)"
             ),
             Arg.create(
                 "print_errs",
                 typ=bool,
                 `default=True,
                 help="Print detailed error messages",
                 short="e"
             ),
             Arg.create(
                 "ignore",
                 kind=ArgKind.MULTI_OPTION,
                 `default=[],
                 help="Directories or files to ignore (space separated)"
             ),
             Arg.create(
                 "disable-error-code",
                 kind=ArgKind.MULTI_OPTION,
                 `default=[],
                 help="Diagnostic codes or lint kebab aliases to suppress (same as [check].suppress in jac.toml; e.g. E1030 no-print)"
             ),
             Arg.create(
                 "parse_only",
                 typ=bool,
                 `default=False,
                 help="Only check syntax (skip type checking)",
                 short="p"
             ),
             Arg.create(
                 "nowarn",
                 typ=bool,
                 `default=False,
                 help="Suppress warning output (warnings are still counted)"
             ),
             Arg.create(
                 "lint",
                 dest="lint_only",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Report lint violations only (absorbs 'jac lint')"
             ),
             Arg.create(
                 "fix",
                 typ=bool,
                 `default=False,
                 short="",
                 help="With --lint: auto-fix violations"
             ),
             Arg.create(
                 "native-coverage",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Compile with codegen and report per-module native outcome (native / demoted / server) ranked by reason (needs the native toolchain)"
             ),
             Arg.create(
                 "placements",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Report where every top-level element was placed (server / client / native / dual) with the evidence behind each decision"
             ),
             Arg.create(
                 "jobs",
                 `default="",
                 short="j",
                 help="Worker processes: a count, 'auto' (one per core, memory-budgeted) or 0 for serial; defaults to [dev] check_jobs / jobs in jac.toml or JAC_CHECK_JOBS / JAC_JOBS"
             ),
             Arg.create(
                 "app",
                 `default="",
                 short="",
                 help="Restrict a workspace check to one [apps.<name>] entry of jac.toml"
             ),

         ],
         examples=[
             (
                 "jac check",
                 "Check every app of the workspace, then the files no app reaches"
             ),
             ("jac check --app web", "Check one app of the workspace"),
             ("jac check myprogram.jac", "Check a single file"),
             (
                 "jac check . --native-coverage",
                 "Rank modules by native compile outcome"
             ),
             ("jac check . --placements", "Show element placements with evidence"),
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
                 "jac check myprogram.jac --parse_only",
                 "Only check syntax, skip type checking"
             ),
             ("jac check myprogram.jac --nowarn", "Check without warnings"),

         ],
         group="analysis",
         handler_name=ct_name(check)
     );

def explain(topic: str, filename: str, output: str = "", memory: str = "") -> int;

def check(
    paths: list,
    print_errs: bool = True,
    ignore: (list | None) = None,
    disable_error_code: (list | None) = None,
    parse_only: bool = False,
    nowarn: bool = False,
    lint_only: bool = False,
    fix: bool = False,
    native_coverage: bool = False,
    placements: bool = False,
    jobs: str = "",
    app: str = ""
) -> int;

def lint(paths: list, fix: bool = False, ignore: (list | None) = None) -> int;

comptime SPEC_FORMAT: CommandSpec = CommandSpec(
         name="fmt",
         help="Format Jac source code",
         tier="core",
         args=[
             Arg.create(
                 "paths",
                 kind=ArgKind.MULTI_POSITIONAL,
                 help="Paths to .jac files or directories"
             ),
             Arg.create(
                 "to_screen",
                 typ=bool,
                 `default=False,
                 help="Print to stdout instead of writing",
                 short="s"
             ),
             Arg.create(
                 "lintfix",
                 typ=bool,
                 `default=False,
                 help="Also apply auto-lint fixes in the same pass",
                 short="l"
             ),
             Arg.create(
                 "check",
                 typ=bool,
                 `default=False,
                 help="Check if files are formatted without modifying them (exit 1 if unformatted)",
                 short="c"
             ),
             Arg.create(
                 "cache",
                 typ=bool,
                 `default=False,
                 help="Skip files already known to be formatted (content + config + version keyed)",
                 short="C"
             ),
             Arg.create(
                 "jobs",
                 `default="",
                 short="j",
                 help="Worker processes: a count, 'auto' (one per core, memory-budgeted) or 0 for serial; defaults to [dev] fmt_jobs / jobs in jac.toml or JAC_FMT_JOBS / JAC_JOBS"
             ),

         ],
         examples=[
             ("jac fmt myfile.jac", "Format a single file"),
             ("jac fmt myproject/", "Format all files in directory"),
             ("jac fmt myfile.jac --to_screen", "Preview formatted output"),
             ("jac fmt . --lintfix", "Format and auto-fix lint violations"),
             ("jac fmt . --check", "Check formatting without modifying files"),

         ],
         group="analysis",
         handler_name=ct_name(format)
     );

def format(
    paths: list,
    to_screen: bool = False,
    lintfix: bool = False,
    check: bool = False,
    cache: bool = False,
    cache_anchor: str = "",
    path_map: dict | None = None,
    cache_stats: dict | None = None,
    jobs: str = ""
) -> int;

comptime SPEC_PRECOMMIT: CommandSpec = CommandSpec(
         name="precommit",
         help="Run fmt (--lintfix) + check using jac.toml lint settings; installable as a git hook",
         hidden=True,
         args=[
             Arg.create(
                 "paths",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Paths to .jac files or directories (default: project root)"
             ),
             Arg.create(
                 "staged",
                 typ=bool,
                 `default=False,
                 help="Only process git-staged .jac files"
             ),
             Arg.create(
                 "verify",
                 typ=bool,
                 `default=False,
                 help="Verify only: do not rewrite files (exit 1 if unformatted)",
                 short="v"
             ),
             Arg.create(
                 "install",
                 typ=bool,
                 `default=False,
                 help="Install git pre-commit + commit-msg hooks"
             ),
             Arg.create(
                 "force",
                 typ=bool,
                 `default=False,
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
         group="analysis",
         handler_name=ct_name(precommit)
     );

def precommit(
    paths: (list | None) = None,
    staged: bool = False,
    verify: bool = False,
    install: bool = False,
    force: bool = False,
    cache_stats: dict | None = None
) -> int;

comptime SPEC_TEST: CommandSpec = CommandSpec(
         name="test",
         help="Run Jac test suite",
         tier="core",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="App name from [apps], or a path to a test file or directory"
             ),
             Arg.create(
                 "paths",
                 kind=ArgKind.MULTI_POSITIONAL,
                 help="More test files or directories",
                 `default=[]
             ),
             Arg.create(
                 "test_name",
                 `default="",
                 help="Run specific test (without test_ prefix)",
                 short="t"
             ),
             Arg.create(
                 "filter",
                 `default="",
                 help="Select tests by name expression (and/or/not, parens)",
                 short="f"
             ),
             Arg.create(
                 "xit",
                 typ=bool,
                 `default=False,
                 help="Stop on first failure",
                 short="x"
             ),
             Arg.create(
                 "maxfail",
                 typ=int,
                 `default=None,
                 help="Stop after N failures",
                 short="m"
             ),
             Arg.create("directory", `default="", help="Test directory", short="d"),
             Arg.create(
                 "collect_only",
                 typ=bool,
                 `default=False,
                 help="List collected test files without running them"
             ),
             Arg.create(
                 "range",
                 dest="pct_range",
                 `default="",
                 short="",
                 help="Run only this percent slice of the plan (N-M, N-, or -M)"
             ),
             Arg.create(
                 "resume",
                 typ=bool,
                 `default=False,
                 help="Restart the plan from the file that failed last run",
                 short="r"
             ),
             Arg.create(
                 "verbose",
                 typ=bool,
                 `default=False,
                 help="Verbose output",
                 short="v",
                 config_key="test.verbose"
             ),
             Arg.create(
                 "ignore",
                 kind=ArgKind.MULTI_OPTION,
                 `default=[],
                 help="Paths to skip during collection (space separated)"
             ),
             Arg.create(
                 "profile",
                 `default="",
                 short="",
                 help="Configuration profile to load (e.g. prod, staging)"
             ),
             Arg.create(
                 "jobs",
                 `default="",
                 short="j",
                 help="Worker processes: a count, 'auto' (one per core, memory-budgeted) or 0 for serial; defaults to [dev] test_jobs / jobs in jac.toml or JAC_TEST_JOBS / JAC_JOBS"
             ),

         ],
         examples=[
             ("jac test", "Run all tests in current directory"),
             ("jac test web", "Run the tests of one app of the workspace"),
             ("jac test mytest.jac", "Run tests in specific file"),
             ("jac test a.jac b.jac", "Run tests in several files"),
             ("jac test --test_name my_test", "Run only test_my_test"),
             ("jac test --xit --verbose", "Stop on first failure with verbose output"),
             ("jac test --collect_only", "List test files without running them"),
             ("jac test --range 15-20", "Run only that percent slice of the plan"),
             ("jac test -x --resume", "Fix-and-continue from the last failure"),

         ],
         group="analysis",
         handler_name=ct_name(`test)
     );

def `test(
    target: str = "",
    paths: list = [],
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    collect_only: bool = False,
    pct_range: str = "",
    resume: bool = False,
    verbose: bool = False,
    ignore: (list | None) = None,
    jobs: str = ""
) -> int;

comptime SPEC_GEN_PARSER: CommandSpec = CommandSpec(
         name="gen_parser",
         hidden=True,
         help="Generate Jac parser (internal use)",
         args=[],
         examples=[("jac gen_parser", "Regenerate the Jac parser"), ],
         group="analysis",
         handler_name=ct_name(gen_parser)
     );

def gen_parser -> int;

def grammar(output: str = "", strict: bool = False) -> int;
