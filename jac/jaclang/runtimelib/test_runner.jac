import os;
import unittest;

glob PASSED: str = "passed",
     FAILED: str = "failed",
     ERROR: str = "error",
     SKIPPED: str = "skipped",
     CRASHED: str = "crashed";

glob _WARNING_IGNORES: list[tuple[str, str, str]] = [
         (
             "HTTPResponse.getheaders\\(\\) is deprecated",
             "DeprecationWarning",
             "kubernetes"
         ),
         (
             "The @wait_container_is_ready decorator is deprecated.*",
             "DeprecationWarning",
             ""
         ),
         (
             "The wait_for_logs function with string or callable predicates is"
             " deprecated.*",
             "DeprecationWarning",
             ""
         ),
         ("", "ResourceWarning", ""),
         ("", "DeprecationWarning", "cattrs"),
         ("", "DeprecationWarning", "jaclang.vendor.cattrs")
     ];

glob _WORKER_MEM_BYTES: int = 2 * 1024 * 1024 * 1024,
     _MEM_HEADROOM: float = 0.6,
     _MAX_AUTO_JOBS: int = 12,
     _PROGRESS_WIDTH: int = 72;

glob _CRASH_LOG: list[str] = [""],
     _TEST_BASES: list[str] = [],
     _TEST_PACKAGES: dict[(str, str)] = {},
     _TEST_PKG_COUNTER: list[int] = [0];

obj TestOutcome {
    has file: str,
        name: str,
        status: str,
        message: str = "",
        duration: float = 0.0;

    def is_failure -> bool;
    def to_wire -> dict[(str, any)];
    static def from_wire(payload: dict[(str, any)]) -> TestOutcome;
}

obj TestPlan {
    has files: list[str],
        explicit: set[str];

    def is_empty -> bool;
}

obj NameFilter {
    has expr: str,
        tree: any = None;

    def postinit -> None;
    def matches(name: str) -> bool;
}

obj JacTestResult(unittest.TestResult) {
    def _exc_info_to_string(err: any, `test: any) -> str;
}

glob EXIT_OK: int = 0,
     EXIT_FAILED: int = 1,
     EXIT_NO_TESTS: int = 5;

obj Reporter {
    has verbose: bool = False,
        stream: any = None,
        column: int = 0,
        counts: dict[(str, int)] postinit,
        failures: list[TestOutcome] postinit;

    def postinit -> None;
    def record(outcome: TestOutcome) -> None;
    def file_crashed(filepath: str, detail: str) -> None;
    def failure_count -> int;
    def total_count -> int;
    def summarize(elapsed: float) -> int;
}

obj ForkPool {
    has plan: TestPlan,
        selector: (NameFilter | None),
        reporter: Reporter,
        jobs: int,
        xit: bool = False,
        maxfail: (int | None) = None,
        cursor: int = 0,
        stopping: bool = False,
        kids: list[dict[(str, any)]] postinit;

    def postinit -> None;
    def run -> None;
    def _pump -> None;
    def _spawn(slot: int) -> dict[(str, any)];
    def _worker_loop(dispatch_fd: int, result_fd: int) -> None;
    def _dispatch(kid: dict[(str, any)]) -> bool;
    def _handle_record(kid: dict[(str, any)], line: str) -> None;
    def _reap(kid: dict[(str, any)]) -> None;
    def _should_stop -> bool;
    def _shutdown -> None;
}

def discover(
    paths: (list[str] | None) = None,
    directory: str = "",
    ignore: (list[str] | None) = None
) -> TestPlan;

def run_file(
    filepath: str,
    selector: (NameFilter | None) = None,
    explicit: bool = False,
    xit: bool = False,
    maxfail: (int | None) = None,
    seen_failures: int = 0
) -> list[TestOutcome];

def run_tests(
    paths: (list[str] | None) = None,
    directory: str = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: (int | None) = None,
    verbose: bool = False,
    ignore: (list[str] | None) = None,
    jobs: (str | int | None) = None
) -> int;

def default_jobs -> int;

def resolve_jobs(requested: (str | int | None) = None) -> int;

def install_warning_filters -> None;

def _tokenize_filter(expr: str) -> list[str];

def _parse_filter_expr(expr: str) -> any;

def _parse_or(toks: list[str], pos: list[int]) -> any;

def _parse_and(toks: list[str], pos: list[int]) -> any;

def _parse_not(toks: list[str], pos: list[int]) -> any;

def _eval_filter(expr_node: any, name: str) -> bool;

def _build_selector(test_name: str, filter: str) -> (NameFilter | None);

def _iter_candidate_files(start: str, ignore: (list[str] | None) = None) -> list[str];

def _should_ignore(path: str, ignore: list[str]) -> bool;

def _under_fixtures(path: str) -> bool;

def _is_named_test_file(filename: str) -> bool;

def _suite_source(filepath: str) -> str;

def _fresh_jac_state(clear_modules: bool = True) -> None;

def _package_basedir(start_dir: str) -> str;

def _outermost_package_root(start_dir: str, ceiling: str) -> str;

def _project_root_for(start_dir: str) -> str;

def _ensure_test_package(base_dir: str) -> str;

def _capture_begin -> dict[(str, any)];

def _capture_end(state: dict[(str, any)]) -> str;

def _cleanup_test_bases -> None;

def _run_serial(
    plan: TestPlan,
    selector: (NameFilter | None),
    reporter: Reporter,
    xit: bool,
    maxfail: (int | None)
) -> None;

import atexit;

with entry {
    atexit.register(_cleanup_test_bases);
}
