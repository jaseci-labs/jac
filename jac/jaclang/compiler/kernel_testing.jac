"""The kernel's own tests: compiler internals tests compiled into the kernel.

A suite is a module in `compiler/kernel_tests/` whose cases are plain functions
that raise on failure; `kernel_suites` lists every suite, in the roster through
this module's imports. `run_case` runs one case with its own scratch directory
and leaves the host neutral afterwards, returning the failure as text (empty
when the case passed). The kernel module's `tests` and `run_tests` functions
reach the suites through `kernel_api.kernel_test_cases` and
`kernel_api.run_kernel_tests`."""
import os;

obj KernelCase {
    has name: str,
        check: Callable[[], None];
}

obj KernelSuite {
    has name: str,
        cases: list[KernelCase];
}

obj CaseScope {
    has scratch: str = "";
}

glob:priv scope: CaseScope = CaseScope();

def kernel_suites -> list[KernelSuite];

def find_suite(name: str) -> KernelSuite;

def run_case(case: KernelCase, scratch: str) -> str;

def case_scratch -> str;
