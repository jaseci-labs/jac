"""Core constructs for Jac Language."""
import unittest;
import from collections.abc { Callable }
import from dataclasses { dataclass }
"""Jac test result class."""
class JacTestResult(unittest.TextTestResult) {
    """Initialize FailFastTestResult object."""
    def init(
        self: JacTestResult,
        stream: Any,
        descriptions: Any,
        verbosity: int,
        max_failures: (int | None) = None
    ) -> None {
        super.init(stream, descriptions, verbosity);
        self.failures_count = JacTestCheck.failcount;
        self.max_failures = max_failures;
    }

    """Count failures and stop."""
    def addFailure(self: JacTestResult, <>test: Any, err: Any) -> None {
        super.addFailure(<>test, err);
        self.failures_count += 1;
        if (
            (self.max_failures is not None)
            and (self.failures_count >= self.max_failures)
        ) {
            self.stop();
        }
    }

    """Stop the test execution."""
    def stop(self: JacTestResult) -> None {
        self.shouldStop = True;
    }
}

"""Jac test runner class."""
class JacTextTestRunner(unittest.TextTestRunner) {
    """Initialize JacTextTestRunner object."""
    def init(
        self: JacTextTestRunner, max_failures: (int | None) = None, **kwargs: Any
    ) -> None {
        self.max_failures = max_failures;
        super.init(**kwargs);
    }

    """Override the method to return an instance of JacTestResult."""
    def _makeResult(self: JacTextTestRunner) -> JacTestResult {
        return JacTestResult(
            self.stream,
            self.descriptions,
            self.verbosity,
            max_failures=self.max_failures
        );
    }
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

    """Clear the test suite."""
    static def reset -> None {
        JacTestCheck.test_case = unittest.TestCase();
        JacTestCheck.test_suite = unittest.TestSuite();
        JacTestCheck.test_suite_path = {};
    }

    """Run the test suite."""
    static def run_test(
        xit: bool,
        maxfail: (int | None),
        verbose: bool,
        filepath: (str | None),
        func_name: (str | None)
    ) -> None {
        verb = 2 if verbose else 1;
        test_suite = JacTestCheck.test_suite;
        if (filepath and filepath.endswith('.test.jac')) {
            filepath = filepath[:-9];
        } elif (filepath and filepath.endswith('.jac')) {
            filepath = filepath[:-4];
        }
        if filepath {
            test_cases = JacTestCheck.test_suite_path.get(filepath);
            if (test_cases is not None) {
                test_suite = unittest.TestSuite();
                for test_case in test_cases {
                    if func_name {
                        if (test_case.func_name == func_name) {
                            test_suite.addTest(test_case.test_case);
                        }
                    } else {
                        test_suite.addTest(test_case.test_case);
                    }
                }
            }
        } elif func_name {
            test_suite = unittest.TestSuite();
            for test_cases in JacTestCheck.test_suite_path.values() {
                for test_case in test_cases {
                    if (test_case.func_name == func_name) {
                        test_suite.addTest(test_case.test_case);
                    }
                }
            }
        }
        runner = JacTextTestRunner(max_failures=maxfail, failfast=xit, verbosity=verb);
        result = runner.run(test_suite);
        if result.wasSuccessful() {
            print('Passed successfully.');
        } else {
            fails = len(result.failures);
            JacTestCheck.failcount += fails;
            JacTestCheck.breaker = (JacTestCheck.failcount >= maxfail)
            if maxfail
            else True;
        }
    }

    """Create a new test."""
    static def add_test(filepath: str, func_name: str, test_func: Callable) -> None {
        if (filepath and filepath.endswith('.test.jac')) {
            filepath = filepath[:-9];
        } elif (filepath and filepath.endswith('.jac')) {
            filepath = filepath[:-4];
        }
        if (filepath not in JacTestCheck.test_suite_path) {
            JacTestCheck.test_suite_path[filepath] = [];
        }
        test_case = unittest.FunctionTestCase(test_func);
        JacTestCheck.test_suite_path[filepath].append(
            JacTestCheck.TestSuite(test_case=test_case, func_name=func_name)
        );
        JacTestCheck.test_suite.addTest(test_case);
    }

    """Make convenient check.Equal(...) etc."""
    def __getattr__(self: JacTestCheck, name: str) -> object {
        return getattr(JacTestCheck.test_case, name);
    }
}
