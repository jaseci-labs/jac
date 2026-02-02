import from jaclang.cli.console { console }

"""Make convenient check.Equal(...) etc."""
impl JacTestCheck.__getattr__(name: str) -> object {
    return getattr(JacTestCheck.test_case, name);
}

"""Create a new test."""
impl JacTestCheck.add_test(filepath: str, func_name: str, test_func: Callable) -> None {
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

"""Run the test suite."""
impl JacTestCheck.run_test(
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
        console.print('Passed successfully.');
    } else {
        fails = len(result.failures);
        JacTestCheck.failcount += fails;
        JacTestCheck.breaker = (JacTestCheck.failcount >= maxfail) if maxfail else True;
    }
}

"""Clear the test suite."""
impl JacTestCheck.reset -> None {
    JacTestCheck.test_case = unittest.TestCase();
    JacTestCheck.test_suite = unittest.TestSuite();
    JacTestCheck.test_suite_path = {};
}

"""Override the method to return an instance of JacTestResult."""
impl JacTextTestRunner._makeResult -> JacTestResult {
    return JacTestResult(
        self.stream, self.descriptions, self.verbosity, max_failures=self.max_failures
    );
}

"""Initialize JacTextTestRunner object."""
impl JacTextTestRunner.init(max_failures: (int | None) = None, **kwargs: Any) -> None {
    self.max_failures = max_failures;
    super.init(**kwargs);
}

"""Stop the test execution."""
impl JacTestResult.stop -> None {
    self.shouldStop = True;
}

"""Count failures and stop."""
impl JacTestResult.addFailure(<>test: Any, err: Any) -> None {
    super.addFailure(<>test, err);
    self.failures_count += 1;
    if ((self.max_failures is not None) and (self.failures_count >= self.max_failures)) {
        self.stop();
    }
}

"""Initialize FailFastTestResult object."""
impl JacTestResult.postinit -> None {
    self.failures_count = JacTestCheck.failcount;
    super.init(self.stream, self.descriptions, self.verbosity);
}
