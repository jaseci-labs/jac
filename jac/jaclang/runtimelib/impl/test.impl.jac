import from jaclang.cli.console { console }
import from jaclang.jac0core.ext_registry { strip_suffix }

impl JacTestCheck.add_test(
    filepath: str, func_name: str, test_func: Callable, display_name: str = ""
) -> None {
    if filepath {
        filepath = strip_suffix(filepath);
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

impl JacTestCheck.run_test(
    xit: bool,
    maxfail: (int | None),
    verbose: bool,
    filepath: (str | None),
    func_name: (str | None)
) -> None {
    verb = 2 if verbose else 1;
    test_suite = JacTestCheck.test_suite;
    if filepath {
        filepath = strip_suffix(filepath);
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

impl JacTestCheck.reset -> None {
    JacTestCheck.test_suite = unittest.TestSuite();
    JacTestCheck.test_suite_path = {};
}

impl JacTextTestRunner._makeResult -> JacTestResult {
    return JacTestResult(
        self.stream, self.descriptions, self.verbosity, max_failures=self.max_failures
    );
}

impl JacTextTestRunner.init(max_failures: (int | None) = None, **kwargs: any) -> None {
    self.max_failures = max_failures;
    super.init(**kwargs);
}

impl JacTestResult.stop -> None {
    self.shouldStop = True;
}

impl JacTestResult.addFailure(`test: any, err: any) -> None {
    super.addFailure(`test, err);
    self.failures_count += 1;
    if (
        (self.max_failures is not None) and (self.failures_count >= self.max_failures)
    ) {
        self.stop();
    }
}

impl JacTestResult.postinit -> None {
    self.failures_count = JacTestCheck.failcount;
    super.init(self.stream, self.descriptions, self.verbosity);
}

impl invoke_native_test(
    engine: any, symbol: str, test_name: str, init_symbols: (list | None) = None
) -> None {
    import ctypes;
    import os;
    import sys;
    import tempfile;
    if engine is None {
        raise RuntimeError(f"native engine unavailable for {test_name}");
    }
    addr = engine.get_function_address(symbol);
    if addr == 0 {
        raise RuntimeError(f"native test symbol missing: {symbol}");
    }
    native_fn = ctypes.CFUNCTYPE(ctypes.c_char_p)(addr);
    def run_glob_inits {
        done = engine?._jac_glob_inits_done;
        if done is None {
            done = set();
            try {
                setattr(engine, "_jac_glob_inits_done", done);
            } except Exception {
                ;
            }
        }
        for init_sym in (init_symbols or []) {
            if init_sym in done {
                continue;
            }
            done.add(init_sym);
            init_addr = engine.get_function_address(init_sym);
            if init_addr {
                (ctypes.CFUNCTYPE(None)(init_addr))();
            }
        }
    }
    mirrors: list = [];
    for (fd, name) in ((1, "stdout"), (2, "stderr")) {
        stream = getattr(sys, name, None);
        stream_fd: (int | None) = None;
        if stream is not None {
            try {
                stream_fd = stream.fileno();
            } except Exception {
                stream_fd = None;
            }
        }
        if stream_fd != fd {
            mirrors.append((fd, name));
        }
    }
    if not mirrors {
        run_glob_inits();
        msg = native_fn();
        if msg is not None {
            raise AssertionError(msg.decode("utf-8", "replace"));
        }
        return;
    }
    saved: dict = {};
    sinks: dict = {};
    for (fd, name) in mirrors {
        saved[fd] = os.dup(fd);
        sink = tempfile.TemporaryFile();
        os.dup2(sink.fileno(), fd);
        sinks[fd] = (sink, name);
    }
    msg: any = None;
    try {
        run_glob_inits();
        msg = native_fn();
    } finally {
        try {
            ctypes.CDLL(None).fflush(None);
        } except Exception {
            ;
        }
        for (fd, (sink, name)) in sinks.items() {
            os.dup2(saved[fd], fd);
            os.close(saved[fd]);
            data = b"";
            try {
                sink.flush();
                sink.seek(0);
                data = sink.read();
            } finally {
                sink.close();
            }
            if data {
                stream = getattr(sys, name, None);
                if stream is not None {
                    try {
                        stream.write(data.decode("utf-8", "replace"));
                    } except Exception {
                        ;
                    }
                }
            }
        }
    }
    if msg is not None {
        raise AssertionError(msg.decode("utf-8", "replace"));
    }
}

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
        def make_fn(p: any) -> Callable {
            def fn {
                test_func(p);
            }
            return fn;
        }
        JacTestCheck.add_test(
            caller_file, func_name, make_fn(param), display_name=display
        );
    }
}
