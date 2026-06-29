import unittest;
import from collections.abc { Callable, Iterable }
import from typing { ClassVar }

obj JacTestResult(unittest.TextTestResult) {
    has stream: any,
        descriptions: any,
        verbosity: int,
        max_failures: (int | None) = None,
        failures_count: int by postinit;

    def postinit -> None;
    def addFailure(`test: any, err: any) -> None;
    def stop -> None;
}

obj JacTextTestRunner(unittest.TextTestRunner) {
    def init(max_failures: (int | None) = None, **kwargs: any) -> None;
    def _makeResult -> JacTestResult;
}

obj JacTestCheck {
    with entry {
        test_suite = unittest.TestSuite();
    }

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
}

def parametrize(
    base_name: str,
    params: Iterable,
    test_func: Callable,
    id_fn: (Callable | None) = None
) -> None;
