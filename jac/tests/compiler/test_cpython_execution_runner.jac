"""Execution coverage must preserve upstream skips without requiring compilation."""
import contextlib;
import importlib;
import io;
import from pathlib { Path }
import sys;
import types;
import unittest;
import from unittest.mock { patch }
import from tests.support { JAC_ROOT }

test "execution mode counts successes while preserving upstream skips" {
    repo = Path(JAC_ROOT).parent;
    script = repo / "scripts/run_cpython_compiler_tests.jac";
    if not script.is_file() {
        testskip("repository test runner is not installed");
    }
    sys.path.insert(0, str(repo));
    try {
        runner = importlib.import_module("scripts.run_cpython_compiler_tests");
    } finally {
        sys.path.pop(0);
    }
    class Probe(unittest.TestCase) {
        def test_plain(self: Probe) {
            self.assertEqual(6 * 7, 42);
        }

        @unittest.skip("upstream skip")
        def test_skipped(self: Probe) {
            self.fail("upstream skip was ignored");
        }
    }
    package = types.ModuleType("test");
    package.__path__ = [];
    support = types.ModuleType("test.support");
    fixture = types.ModuleType("test.evaluator_probe");
    fixture.Probe = Probe;
    modules = {
        "test": package,
        "test.support": support,
        "test.evaluator_probe": fixture
    };
    args = types.SimpleNamespace(
        cache=repo,
        module="test.evaluator_probe",
        compile_tests=False,
        execution_tests=False,
        symtable_api=False,
        tokenize_api=False,
        native_modules=[],
        tests=None
    );
    with patch.dict(sys.modules, modules), patch.object(
        runner, "fetch_tests", return_value=repo
    ) {
        for execution in [False, True] {
            args.execution_tests = execution;
            stdout = io.StringIO();
            stderr = io.StringIO();
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(
                stderr
            ) {
                assert runner.run_tests(args, [0]) == 0;
            }
            expected = "skipped=1" if execution else "skipped=2";
            assert expected in stderr.getvalue() , stderr.getvalue();
            assert "upstream skip" in stderr.getvalue();
            assert ("no direct call to JacPython" in stderr.getvalue())
                == (not execution);
            assert ("evaluator provenance is not asserted" in stdout.getvalue())
                == execution;
        }
    }
}

test "a module that skips itself on import is reported as skipped" {
    repo = Path(JAC_ROOT).parent;
    script = repo / "scripts/run_cpython_compiler_tests.jac";
    if not script.is_file() {
        testskip("repository test runner is not installed");
    }
    sys.path.insert(0, str(repo));
    try {
        runner = importlib.import_module("scripts.run_cpython_compiler_tests");
    } finally {
        sys.path.pop(0);
    }
    package = types.ModuleType("test");
    package.__path__ = [];
    modules = {"test": package, "test.support": types.ModuleType("test.support")};
    args = types.SimpleNamespace(
        cache=repo,
        module="test.other_platform_probe",
        compile_tests=False,
        execution_tests=True,
        symtable_api=False,
        tokenize_api=False,
        native_modules=[],
        tests=None
    );
    real_import = importlib.import_module;
    def import_or_skip(name: str) -> types.ModuleType {
        if name == "test.other_platform_probe" {
            raise unittest.SkipTest("test works only on another platform");
        }
        return real_import(name);
    }
    stderr = io.StringIO();
    with patch.dict(sys.modules, modules), patch.object(
        runner, "fetch_tests", return_value=repo
    ), patch.object(importlib, "import_module", side_effect=import_or_skip), contextlib.redirect_stderr(
        stderr
    ) {
        assert runner.run_tests(args, [0]) == 0;
    }
    assert "test.other_platform_probe skipped: test works only on another platform"
        in stderr.getvalue() , stderr.getvalue();
}

test "a test can start a child process that imports from the test library" {
    import multiprocessing;
    import tempfile;
    repo = Path(JAC_ROOT).parent;
    script = repo / "scripts/run_cpython_compiler_tests.jac";
    if not script.is_file() {
        testskip("repository test runner is not installed");
    }
    sys.path.insert(0, str(repo));
    try {
        runner = importlib.import_module("scripts.run_cpython_compiler_tests");
    } finally {
        sys.path.pop(0);
    }
    seen: dict[str, object] = {};
    class Probe(unittest.TestCase) {
        def test_spawned_child(self: Probe) {
            seen["main"] = sys.modules["__main__"];
            child = multiprocessing.get_context("spawn").Process(
                target=importlib.import_module, args=("library_only_probe", )
            );
            child.start();
            child.join(60);
            self.assertEqual(child.exitcode, 0);
        }
    }
    package = types.ModuleType("test");
    package.__path__ = [];
    fixture = types.ModuleType("test.child_process_probe");
    fixture.Probe = Probe;
    modules = {
        "test": package,
        "test.support": types.ModuleType("test.support"),
        "test.child_process_probe": fixture
    };
    main_before = sys.modules["__main__"];
    with tempfile.TemporaryDirectory() as library {
        (Path(library) / "library_only_probe.py").write_text("VALUE = 1\n");
        args = types.SimpleNamespace(
            cache=repo,
            module="test.child_process_probe",
            compile_tests=False,
            execution_tests=True,
            symtable_api=False,
            tokenize_api=False,
            native_modules=[],
            tests=None
        );
        stderr = io.StringIO();
        with patch.dict(sys.modules, modules), patch.object(
            runner, "fetch_tests", return_value=Path(library)
        ), contextlib.redirect_stderr(stderr) {
            assert runner.run_tests(args, [0]) == 0 , stderr.getvalue();
        }
        assert library not in sys.path;
    }
    assert seen["main"] is not main_before;
    assert sys.modules["__main__"] is main_before;
}
