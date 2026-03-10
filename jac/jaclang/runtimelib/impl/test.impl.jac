import from jaclang.cli.console { console }

"""Make convenient check.Equal(...) etc."""
impl JacTestCheck.__getattr__(name: str) -> object {
    return getattr(JacTestCheck.test_case, name);
}

"""Create a new test."""
impl JacTestCheck.add_test(
    filepath: str, func_name: str, test_func: Callable, display_name: str = ""
) -> None {
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
        JacTestCheck.TestSuite(
            test_case=test_case,
            func_name=func_name,
            display_name=display_name or func_name
        )
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
impl JacTestResult.addFailure(`test: Any, err: Any) -> None {
    super.addFailure(`test, err);
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

"""Register one test per parameter (like pytest.mark.parametrize)."""
impl parametrize(
    base_name: str,
    params: Iterable,
    test_func: Callable,
    id_fn: (Callable | None) = None
) -> None {
    import from inspect { stack }
    caller_file = stack()[1].filename;
    for param in params {
        param_id = id_fn(param) if id_fn else str(param);
        display = f"{base_name} [{param_id}]";
        func_name = f"{base_name}_{param_id}";
        def make_fn(p: Any) -> Callable {
            def fn -> None {
                test_func(p);
            }
            return fn;
        }
        JacTestCheck.add_test(
            caller_file, func_name, make_fn(param), display_name=display
        );
    }
}
