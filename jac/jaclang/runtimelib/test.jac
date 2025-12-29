"""Core constructs for Jac Language."""
import unittest;
import from collections.abc { Callable }
import from dataclasses { dataclass }
"""Jac test result class."""
class JacTestResult(unittest.TextTestResult) {
    def init(
        self: JacTestResult,
        stream: Any,
        descriptions: Any,
        verbosity: int,
        max_failures: (int | None) = None
    ) -> None;

    def addFailure(self: JacTestResult, <>test: Any, err: Any) -> None;
    def stop(self: JacTestResult) -> None;
}

"""Jac test runner class."""
class JacTextTestRunner(unittest.TextTestRunner) {
    def init(
        self: JacTextTestRunner, max_failures: (int | None) = None, **kwargs: Any
    ) -> None;

    def _makeResult(self: JacTextTestRunner) -> JacTestResult;
}

"""Jac Testing and Checking."""
class JacTestCheck {
    with entry {
        test_case = unittest.TestCase();
        test_suite = unittest.TestSuite();
    }

    """Test Suite."""
    @dataclass
    class TestSuite {
        with entry {
            test_case: unittest.FunctionTestCase;
            func_name: str;
        }
    }

    with entry {
        test_suite_path: <>dict[(str, <>list[TestSuite])] = {};
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

    static def add_test(filepath: str, func_name: str, test_func: Callable) -> None;
    def __getattr__(self: JacTestCheck, name: str) -> object;
}
