"""Core constructs for Jac Language."""
import unittest;
import from collections.abc { Callable, Iterable }
import from typing { ClassVar }
"""Jac test result class."""
obj JacTestResult(unittest.TextTestResult) {
    has stream: Any,
        descriptions: Any,
        verbosity: int,
        max_failures: (int | None) = None,
        failures_count: int by postinit;

    def postinit -> None;
    def addFailure(`test: Any, err: Any) -> None;
    def stop -> None;
}

"""Jac test runner class."""
obj JacTextTestRunner(unittest.TextTestRunner) {
    def init(max_failures: (int | None) = None, **kwargs: Any) -> None;
    def _makeResult -> JacTestResult;
}

"""Jac Testing and Checking."""
obj JacTestCheck {
    with entry {
        test_case = unittest.TestCase();
        test_suite = unittest.TestSuite();
    }

    """Test Suite."""
    obj TestSuite {
        with entry {
            test_case: unittest.FunctionTestCase;
            func_name: str;
            display_name: str;
        }
    }

    with entry {
        test_suite_path: ClassVar[dict[(str, list[TestSuite])]] = {};
        breaker = False;
        failcount = 0;
    }

    static def reset -> None;
    static def run_test(
        xit: bool,
        maxfail: (int | None),
        verbose: bool,
        filepath: (str | None),
        func_name: (str | None)
    ) -> None;

    static def add_test(
        filepath: str, func_name: str, test_func: Callable, display_name: str = ""
    ) -> None;

    def __getattr__(name: str) -> object;
}

"""Register one test per parameter (like pytest.mark.parametrize)."""
def parametrize(
    base_name: str,
    params: Iterable,
    test_func: Callable,
    id_fn: (Callable | None) = None
) -> None;
