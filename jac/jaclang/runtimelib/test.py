"""Core constructs for Jac Language."""

from __future__ import annotations

import unittest
from collections.abc import Callable
from dataclasses import dataclass


class JacTestResult(unittest.TextTestResult):
    """Jac test result class."""

    def __init__(
        self,
        stream,  # noqa
        descriptions,  # noqa
        verbosity: int,
        max_failures: int | None = None,
    ) -> None:
        """Initialize FailFastTestResult object."""
        super().__init__(stream, descriptions, verbosity)  # noqa
        self.failures_count = JacTestCheck.failcount
        self.max_failures = max_failures

    def addFailure(self, test, err) -> None:  # noqa
        """Count failures and stop."""
        super().addFailure(test, err)
        self.failures_count += 1
        if self.max_failures is not None and self.failures_count >= self.max_failures:
            self.stop()

    def stop(self) -> None:
        """Stop the test execution."""
        self.shouldStop = True


class JacTextTestRunner(unittest.TextTestRunner):
    """Jac test runner class."""

    def __init__(self, max_failures: int | None = None, **kwargs) -> None:  # noqa
        """Initialize JacTextTestRunner object."""
        self.max_failures = max_failures
        super().__init__(**kwargs)

    def _makeResult(self) -> JacTestResult:  # noqa
        """Override the method to return an instance of JacTestResult."""
        return JacTestResult(
            self.stream,
            self.descriptions,
            self.verbosity,
            max_failures=self.max_failures,
        )


class JacTestCheck:
    """Jac Testing and Checking."""

    test_case = unittest.TestCase()
    test_suite = unittest.TestSuite()

    @dataclass
    class TestSuite:
        """Test Suite."""

        test_case: unittest.FunctionTestCase
        func_name: str

    test_suite_path: dict[str, list[TestSuite]] = {}

    breaker = False
    failcount = 0

    @staticmethod
    def reset() -> None:
        """Clear the test suite."""
        JacTestCheck.test_case = unittest.TestCase()
        JacTestCheck.test_suite = unittest.TestSuite()
        JacTestCheck.test_suite_path = {}

    @staticmethod
    def run_test(
        xit: bool,
        maxfail: int | None,
        verbose: bool,
        filepath: str | None,
        func_name: str | None,
    ) -> None:
        """Run the test suite."""
        verb = 2 if verbose else 1
        test_suite = JacTestCheck.test_suite

        if filepath and filepath.endswith(".test.jac"):
            filepath = filepath[:-9]
        elif filepath and filepath.endswith(".jac"):
            filepath = filepath[:-4]

        if filepath:
            test_cases = JacTestCheck.test_suite_path.get(filepath)
            if test_cases is not None:
                test_suite = unittest.TestSuite()
                for test_case in test_cases:
                    if func_name:
                        if test_case.func_name == func_name:
                            test_suite.addTest(test_case.test_case)
                    else:
                        test_suite.addTest(test_case.test_case)

        elif func_name:
            test_suite = unittest.TestSuite()
            for test_cases in JacTestCheck.test_suite_path.values():
                for test_case in test_cases:
                    if test_case.func_name == func_name:
                        test_suite.addTest(test_case.test_case)

        runner = JacTextTestRunner(max_failures=maxfail, failfast=xit, verbosity=verb)
        result = runner.run(test_suite)
        if result.wasSuccessful():
            print("Passed successfully.")
        else:
            fails = len(result.failures)
            JacTestCheck.failcount += fails
            JacTestCheck.breaker = (
                (JacTestCheck.failcount >= maxfail) if maxfail else True
            )

    @staticmethod
    def add_test(filepath: str, func_name: str, test_func: Callable) -> None:
        """Create a new test."""
        if filepath and filepath.endswith(".test.jac"):
            filepath = filepath[:-9]
        elif filepath and filepath.endswith(".jac"):
            filepath = filepath[:-4]

        if filepath not in JacTestCheck.test_suite_path:
            JacTestCheck.test_suite_path[filepath] = []

        test_case = unittest.FunctionTestCase(test_func)
        JacTestCheck.test_suite_path[filepath].append(
            JacTestCheck.TestSuite(test_case=test_case, func_name=func_name)
        )
        JacTestCheck.test_suite.addTest(test_case)

    def __getattr__(self, name: str) -> object:
        """Make convenient check.Equal(...) etc."""
        return getattr(JacTestCheck.test_case, name)
