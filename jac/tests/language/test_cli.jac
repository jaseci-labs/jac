"""Test Jac cli module."""

import io;
import inspect;
import json;
import os;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import traceback;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.cli.commands {
    analysis,
    cli_helpers,
    execution,
    project,
    tools,
    transform
}
import from jaclang.cli.commands { config as config_cmd }
import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
import from jaclang.compiler.tools.unparse_pass { unparse_module }
import from jaclang.project.config { set_config }
import from jaclang.runtime.builtin { printgraph }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     _template_state = {"initialized": False},
     _CONFIG_TOML = (
         '[project]\nname = "test-project"\nversion = "1.0.0"\n'
         'description = "A test project"\n\n'
         '[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n'
     );

def fixture_path(filename: str) -> str {
    return os.path.join(FIXTURES, filename);
}

def _assert_error_pretty_found(needle: str, haystack: str) {
    for line in [
        line.strip()
        for line in needle.splitlines()
        if line.strip()
    ] {
        assert line in haystack , f"Expected line not found in:\n{haystack}";
    }
}

"""Run jac check and return file count."""
def _run_jac_check(test_dir: str, ignore_pattern: (list | None) = None) -> int {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        analysis.check([test_dir], ignore=ignore_pattern or []);
        stdout = captured_stdout.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    combined = stdout + stderr;
    # New format: "=== N passed in X.XXs ==="
    match_result = re.search(r"(\d+) passed", combined);
    return int(match_result.group(1)) if match_result else 0;
}

# Helper functions for clean command tests
"""Create a minimal jac project structure for testing."""
def _create_clean_project(tmpdir: str) -> str {
    project_path = os.path.join(tmpdir, "testproj");
    os.makedirs(project_path, exist_ok=True);

    toml_content = "[project]\nname = \"testproj\"\nversion = \"0.1.0\"\n";
    with open(os.path.join(project_path, "jac.toml"), "w") as f {
        f.write(toml_content);
    }

    os.makedirs(os.path.join(project_path, ".jac"), exist_ok=True);
    return project_path;
}

"""Set up output capture and return (stdout_capture, stderr_capture, old_stdout, old_stderr)."""
def _capture_output -> tuple {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;
    return (captured_stdout, captured_stderr, old_stdout, old_stderr);
}

"""Restore original stdout/stderr."""
def _restore_output(old_stdout: object, old_stderr: object) {
    sys.stdout = old_stdout;
    sys.stderr = old_stderr;
}

"""Reset the global config cache to force rediscovery."""
def _reset_config {
    import from jaclang.project { config as config_module }
    config_module._config = None;
}

"""Ensure template registry is initialized once."""
def _ensure_template_registry {
    initialized = _template_state.get("initialized", False);
    if not initialized {
        import from jaclang.project.template_registry { initialize_template_registry }
        initialize_template_registry();
        _template_state["initialized"] = True;
    }
}

test "jac cli run" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("hello.jac"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "Hello World!" in stdout_value;
}

test "proc_file strips compound codespace suffixes to bare module stem" {
    # Issue #6696: `jac run`/`jac run --serve` failed on `.sv.jac` / `.jac`
    # entries because proc_file stripped only the trailing `.jac`, leaving
    # e.g. `main.sv`, which the meta-importer misread as the package `main.sv`
    # ("No module named 'main.sv'"). Every compound codespace suffix must
    # collapse to the bare stem so the meta-importer can resolve it.
    cases = [
        ("proj/main.jac", "main"),
        ("proj/main.jac", "main"),
        ("proj/main.jac", "main"),
        ("proj/server.py", "server"),

    ];
    for (filename, expected) in cases {
        (base, mod, mach) = cli_helpers.proc_file(filename);
        try {
            assert mod == expected , (
                f"proc_file({filename!r}) -> module {mod!r}, expected {expected!r}"
            );
        } finally {
            mach.close();
        }
    }
}

test "diagnostics flag" {
    err_file = os.path.join(
        JAC_ROOT, "tests", "compiler", "fixtures", "new_keyword_err.jac"
    );

    # Default (diagnostics="error"): errors shown, returns 1
    captured_out = io.StringIO();
    captured_err = io.StringIO();
    sys.stdout = captured_out;
    sys.stderr = captured_err;
    try {
        result = execution.run(err_file);
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    combined = captured_out.getvalue() + captured_err.getvalue();
    assert "`new(target, ...args)`" in combined , (
        "Detailed errors should appear by default"
    );
    assert result == 1 , "Should return exit code 1 on errors";

    # diagnostics="all": errors shown
    captured_out2 = io.StringIO();
    captured_err2 = io.StringIO();
    sys.stdout = captured_out2;
    sys.stderr = captured_err2;
    try {
        result2 = execution.run(err_file, diagnostics="all");
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    combined2 = captured_out2.getvalue() + captured_err2.getvalue();
    assert "`new(target, ...args)`" in combined2 , (
        "Detailed errors should appear with diagnostics=all"
    );
    assert result2 == 1 , "Should return exit code 1 on errors";

    # diagnostics="none": no errors shown, returns 0
    captured_out3 = io.StringIO();
    captured_err3 = io.StringIO();
    sys.stdout = captured_out3;
    sys.stderr = captured_err3;
    try {
        result3 = execution.run(err_file, diagnostics="none");
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    combined3 = captured_out3.getvalue() + captured_err3.getvalue();
    assert "`new(target, ...args)`" not in combined3 , (
        "Errors should not appear with diagnostics=none"
    );
    assert result3 == 0 , "Should return exit code 0 with diagnostics=none";
}

test "jac cli run python file" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("python_run_test.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "Hello from Python!" in stdout_value;
    assert "This is a test Python file." in stdout_value;
    assert "Result: 42" in stdout_value;
    assert "Python execution completed." in stdout_value;
    assert "10" in stdout_value;
}

test "jac run with no filename and no resolvable entry errors cleanly" {
    # `jac run` with no file is now project-aware: it climbs to the nearest
    # jac.toml and dispatches on the project kind. JAC_ROOT's project declares
    # no entry-point, so this must fail with a clear message (not a crash).
    env = dict(os.environ);
    env["PYTHONPATH"] = JAC_ROOT;
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run"],
        cwd=JAC_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    );
    combined = result.stdout + result.stderr;
    assert result.returncode != 0 , (
        f"Expected non-zero exit for bare jac run; got:\n{combined}"
    );
    assert ("entry-point" in combined) or ("jac.toml" in combined) , (
        f"Expected a project-aware run error; got:\n{combined}"
    );
    assert "NoneType" not in combined , (
        f"Should not crash with TypeError; got:\n{combined}"
    );
}

test "jac run py fstr" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("pyfunc_fstr.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "Hello Peter" in stdout_value;
    assert "Hello Peter Peter" in stdout_value;
    assert "Peter squared is Peter Peter" in stdout_value;
    assert "PETER!  wrong poem" in stdout_value;
    assert "Hello Peter , yoo mother is Mary. Myself, I am Peter." in stdout_value;
    assert "Left aligned: Apple | Price: 1.23" in stdout_value;
}

test "jac run py fmt" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("pyfunc_fmt.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "One" in stdout_value;
    assert "Two" in stdout_value;
    assert "Three" in stdout_value;
    assert "baz" in stdout_value;
    assert "Processing..." in stdout_value;
    assert "Four" in stdout_value;
    assert "The End." in stdout_value;
}

test "jac run pyfunc kwesc" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("pyfunc_kwesc.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    out = stdout_value.split("\n");
    assert "89" in out[0];
    assert "(13, (), {'a': 1, 'b': 2})" in out[1];
    assert "Functions: [{'name': 'replace_lines'" in out[2];
    assert "Dict: 90" in out[3];
}

test "jac cli alert based err" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        execution.run(fixture_path("err2.jac"), entry_name="speak", args=[]);
    } except Exception as e {
        print(f"Error: {e}");
    }
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    assert "Error" in stdout_value;
}

test "jac cli error output has no raw ansi codes" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        execution.run(
            os.path.join(
                JAC_ROOT, "tests", "compiler", "fixtures", "new_keyword_err.jac"
            )
        );
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    output = captured_output.getvalue();
    # Ensure the error was actually reported
    assert "`new(target, ...args)`" in output;
    # Raw ANSI escape codes (\x1b[) must not appear in error output.
    # The console layer handles styling; pretty_print should not inject raw codes.
    assert "\x1b[" not in output , f"Raw ANSI escape codes found in error output:\n{repr(
        output[:500]
    )}";
}

test "jac cli alert based runtime err" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        result = execution.run(fixture_path("err_runtime.jac"));
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }

    assert result == 1;
    output = captured_output.getvalue();

    expected_stderr_values = (
        "Error: list index out of range",
        "    print(some_list[invalid_index]);",
        "          ^^^^^^^^^^^^^^^^^^^^^^^^",
        "  at bar() ",
        "  at foo() ",
        "  at <module> ",
        "... [internal runtime calls]"
    );
    for exp in expected_stderr_values {
        assert exp in output;
    }

    internal_call_patterns = (
        "meta_importer.py",
        "runtime.py",
        "/jaclang/vendor/",
        "pluggy",
        "_multicall",
        "_hookexec"
    );
    for pattern in internal_call_patterns {
        assert pattern not in output;
    }
}

test "jac impl err" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        execution.run(fixture_path("err.jac"), entry_name="speak", args=[]);
    } except Exception {
        traceback.print_exc();
    }
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    path_to_file = fixture_path("err.impl.jac");
    assert f'"{path_to_file}", line 2' in stdout_value;
}

test "param name diff warns" {
    import from jaclang.compiler.driver.program { JacProgram }
    prog = JacProgram();
    prog.compile(fixture_path("decl_defn_param_name.jac"), no_cgen=True);
    warn_msgs = [str(w) for w in prog.warnings_had];
    assert any(
        "'some_long_paramenter_name'" in m and "'short_name'" in m for m in warn_msgs
    ) , (f"Expected param name mismatch warning for method1, got: {warn_msgs}");
    assert any("'param1'" in m and "'p1'" in m for m in warn_msgs) , (
        f"Expected param name mismatch warning for method2 param1, got: {warn_msgs}"
    );
    assert any("'param2'" in m and "'p2'" in m for m in warn_msgs) , (
        f"Expected param name mismatch warning for method2 param2, got: {warn_msgs}"
    );
}

test "jac test err" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    analysis.`test(paths=[fixture_path("baddy.jac")]);
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    # the runner points the failure at <file>:<line> -- the deliberate error is on
    # line 2 of the base module's test annex.
    assert "baddy.test.jac:2" in stdout_value;
}

test "ast print" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.tool("ir", ["ast", f"{fixture_path('hello.jac')}"]);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "+-- Token" in stdout_value;
}

test "ast printgraph" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.tool("ir", ["ast.", f"{fixture_path('hello.jac')}"]);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert 'label="MultiString"' in stdout_value;
}

test "cfg printgraph" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.tool("ir", ["cfg.", f"{fixture_path('hello.jac')}"]);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    correct_graph = (
        "digraph G {\n"
        + '  0 [label="BB0\\ndef still_there\\nprint ( \\"im still here\\" ) ;", shape=box];\n'
        + '  1 [label="BB1\\n\\"Hello World!\\" |> print ;", shape=box];\n'
        + "}\n\n"
    );
    assert correct_graph == stdout_value;
}

test "del clean" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.check([fixture_path("del_clean.jac")]);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "passed" in stdout_value;
}

test "run test" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.`test(paths=[fixture_path("run_test.jac")], maxfail=2);
        out = captured.getvalue();
    } finally {
        sys.stdout = old_stdout;
    }

    # jac test reports on stdout; --maxfail 2 stops the
    # run after the 2nd failure.
    assert "2 failed" in out;
    assert "run_test.jac" in out;
}

test "run test native codespace file" {
    # A compound-codespace test file (`foo.jac`) must collect and run its
    # `test` blocks. Regression for issue #7150: the collector derived
    # the module name with `Path(...).stem`, leaving the `.na` suffix so the
    # import resolved as a package path, failed, and was silently swallowed --
    # 0 items collected, exit 0, CI green while running nothing.
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.`test(paths=[fixture_path("native_run_test.jac")], maxfail=2);
        out = captured.getvalue();
    } finally {
        sys.stdout = old_stdout;
    }

    assert "native_run_test.jac" in out;
    # One block passes and one fails -- proving both were actually collected
    # and executed (not silently skipped as "no tests ran").
    assert "1 failed" in out;
    assert "1 passed" in out;
    assert "no tests ran" not in out;
}

test "run test native broken import surfaces error" {
    # A test file that was explicitly collected but fails to import must be a
    # collection error, not an empty (silently passing) result (issue #7150).
    # Since the native error gate (issue #7239) the failure surfaces at
    # compile time: the unresolvable imported symbol makes native codegen
    # error, the module publishes no artifact, and the collection error
    # carries the compiler diagnostics naming that symbol and the file.
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        rc = analysis.`test(paths=[fixture_path("native_broken_import_test.jac")]);
        out = captured.getvalue();
    } finally {
        sys.stdout = old_stdout;
    }

    # Non-zero exit and a visible error -- never a silent green pass. With
    # the .na.jac marker retired the module demotes to the server codespace,
    # so the broken import surfaces as the loud python import error instead
    # of a native E5090; the never-silently-green guarantee is unchanged.
    assert rc != 0;
    assert "this_module_does_not_exist_7150" in out;
    assert "passed" not in out;
}

test "directory discovery skips impl annexes and dedupes test annexes" {
    # Collection rules, asserted against the runner's discovery directly, on a
    # tree built for the purpose. The end-to-end CLI path for the same rules
    # lives in tests/cli/test_test_discovery.jac.
    import from jaclang.testing.test_runner { discover }
    tree_root = tempfile.mkdtemp();
    try {
        Path(os.path.join(tree_root, "widget.jac")).write_text("def area -> int;\n");
        Path(os.path.join(tree_root, "widget.impl.jac")).write_text(
            "impl area -> int {\n    return 4;\n}\n"
        );
        Path(os.path.join(tree_root, "widget.test.jac")).write_text(
            'test "widget area" {\n    assert area() == 4;\n}\n'
        );
        Path(os.path.join(tree_root, "plain_suite.jac")).write_text(
            'test "plain" {\n    assert True;\n}\n'
        );
        os.makedirs(os.path.join(tree_root, "fixtures"));
        trap = os.path.join(tree_root, "fixtures", "input.jac");
        Path(trap).write_text('test "never collected" {\n    assert False;\n}\n');

        names = [os.path.basename(f) for f in discover(directory=tree_root).files];
        # An impl annex is never a suite.
        assert "widget.impl.jac" not in names;
        # A .test.jac annex resolves to its base module, so the pair collects
        # once, reported under the base rather than the annex.
        assert "widget.test.jac" not in names;
        assert "widget.jac" in names;
        # Every .jac under a declared [test] tree_root is a suite (#7151), even one
        # whose name follows no test-naming convention.
        assert "plain_suite.jac" in names;
        # A fixtures/ input is a test input, not a suite.
        assert "input.jac" not in names;

        # ... but naming a fixtures/ file directly still collects it.
        explicit = [os.path.basename(f) for f in discover(paths=[trap]).files];
        assert explicit == ["input.jac"];
    } finally {
        shutil.rmtree(tree_root, ignore_errors=True);
    }
}

test "discovery prunes hidden and pycache dirs" {
    tmp_dir = tempfile.mkdtemp();
    try {
        os.makedirs(os.path.join(tmp_dir, ".jac"));
        os.makedirs(os.path.join(tmp_dir, "__pycache__"));
        # A real, top-level test that must be discovered and pass.
        Path(os.path.join(tmp_dir, "good_test.jac")).write_text(
            'test "good_one" {\n    assert True;\n}\n'
        );
        # Failing tests planted inside the build-cache (".jac") and pycache
        # dirs. The discovery walk must prune these, so they never run.
        Path(os.path.join(tmp_dir, ".jac", "skip_test.jac")).write_text(
            'test "pruned_cache" {\n    assert False;\n}\n'
        );
        Path(os.path.join(tmp_dir, "__pycache__", "skip_test.jac")).write_text(
            'test "pruned_pyc" {\n    assert False;\n}\n'
        );
        # A declared `-d` root collects every .jac beneath it regardless of
        # naming (#7151), so good_test.jac is a suite even without a test_
        # prefix.
        env = dict(os.environ);
        env["JAC_TEST_JOBS"] = "0";
        process = subprocess.Popen(
            ["jac", "test", "-d", tmp_dir, "-v"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            env=env
        );
        (stdout, stderr) = process.communicate();
        combined = stdout + stderr;
        # Top-level test is discovered and runs to a pass.
        assert "good_test.jac" in combined;
        assert "1 passed" in combined;
        # Hidden / pycache dirs are pruned: their failing tests never run.
        assert "skip_test.jac" not in combined;
        assert "FAILED" not in combined;
        assert process.returncode == 0;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "maxfail spans several files" {
    # --maxfail counts across the whole run, not per file. Serial so the
    # cap trips deterministically rather than racing parallel workers.
    env = dict(os.environ);
    env["JAC_TEST_JOBS"] = "0";
    process = subprocess.Popen(
        [
            "jac",
            "test",
            "maxfail_run_test.jac",
            "run_test.jac",
            "native_run_test.jac",
            "-m",
            "4"
        ],
        cwd=fixture_path(""),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        env=env
    );
    (stdout, stderr) = process.communicate();
    combined = stdout + stderr;
    # -m 4 lets all three files run before the failure cap trips.
    assert "4 failed" in combined;
    assert process.returncode != 0;
}

test "run specific test only" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.`test(
            paths=[fixture_path("jactest_main.jac")],
            test_name="from 2 to 10",
            verbose=True
        );
        out = captured.getvalue();
    } finally {
        sys.stdout = old_stdout;
    }

    # --test_name joins its words with `and`, so only the matching block runs.
    assert "1 passed" in out;
    assert "from 2 to 10" in out;
    assert "first two" not in out;
}


test "graph coverage" {
    graph_params = set(inspect.signature(tools.dot).parameters.keys());
    printgraph_params = set(inspect.signature(printgraph).parameters.keys());
    printgraph_params = printgraph_params - {"nd", "file", "edge_type"};
    printgraph_params.update({"initial", "saveto", "connection", "session"});
    assert printgraph_params.issubset(graph_params);
    assert len(printgraph_params) + 2 == len(graph_params);
}

test "graph" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.dot(
            os.path.join(
                JAC_ROOT, "tests", "compiler", "fixtures", "micro", "simple_walk.jac"
            )
        );
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    if os.path.exists("simple_walk.dot") {
        os.remove("simple_walk.dot");
    }
    assert ">>> Graph content saved to" in stdout_value;
    assert "simple_walk.dot\n" in stdout_value;
}

test "py to jac" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        transform.py2jac(f"{fixture_path('pyfunc.py')}");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "def my_print(x: object) -> None" in stdout_value;
    assert "class MyClass {" in stdout_value;
    assert '"""Print function."""' in stdout_value;
}

test "py to jac line continuation does not drop file" {
    # #6928: implicit string concat joined by a `\` line-continuation used to
    # leak the backslash into the emitted Jac, so py2jac exited 0 while writing
    # empty stdout -- silently dropping the file in a batch port.
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = transform.py2jac(fixture_path("py2jac_line_continuation.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert result == 0 , f"py2jac should succeed, got exit {result}";
    assert stdout_value.strip() , "py2jac must not emit empty output on success";
    assert "\\\n" not in stdout_value , f"Stray line-continuation in:\n{stdout_value}";
    assert '"hello " "world"' in stdout_value , f"Expected folded concat in:\n{stdout_value}";
}

test "lambda arg annotation" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        transform.jac2py(f"{fixture_path('lambda_arg_annotation.jac')}");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "x = lambda a, b: b + a" in stdout_value;
    assert "y = lambda: 567" in stdout_value;
    assert "f = lambda x: 'even' if x % 2 == 0 else 'odd'" in stdout_value;
}

test "lambda self" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        transform.jac2py(f"{fixture_path('lambda_self.jac')}");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "def travel(self, here: City) -> None:" in stdout_value;
    assert "def foo(a: int) -> None:" in stdout_value;
    assert "x = lambda a, b: b + a" in stdout_value;
    assert "def visit_city(self, c: City) -> None:" in stdout_value;
    assert "sorted(users, key=lambda x: x['email'], reverse=True)" in stdout_value;
}

test "param arg" {
    import from jaclang.compiler.driver.program { JacProgram }

    filename = fixture_path("params/test_complex_params.jac");
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    # Bound before the try so a failure ahead of the temp-file write surfaces
    # as itself rather than as an UnboundLocalError from the cleanup.
    jac_file_path = "";
    try {
        transform.jac2py(f"{fixture_path('params/test_complex_params.jac')}");
        py_code = JacProgram().compile(file_path=filename).gen.py;

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".py", delete=False
        ) as temp_file {
            temp_file.write(py_code);
            py_file_path = temp_file.name;
        }

        try {
            jac_code = unparse_module(
                JacProgram().compile(use_str=py_code, file_path=py_file_path)
            );
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as temp_file {
                temp_file.write(jac_code);
                jac_file_path = temp_file.name;
            }
            execution.run(jac_file_path);
        } finally {
            os.remove(py_file_path);
            if jac_file_path {
                os.remove(jac_file_path);
            }
        }
    } finally {
        sys.stdout = old_stdout;
    }

    stdout_lines = [
        l
        for l in captured.getvalue().split("\n")
        if l.strip()
    ];
    expected = [
        "ULTIMATE_MIN: 1|def|2.5|0|test|100|0",
        "ULTIMATE_FULL: 1|custom|3.14|3|req|200|1",
        "SEPARATORS: 42",
        "EDGE_MIX: 1-test-2-True-1",
        "RECURSIVE: 7 11",
        "VALIDATION: x:1,y:2.5,z:10,args:1,w:True,kwargs:1"
    ];
    for line in expected {
        assert line in stdout_lines , f"Expected '{line}' in output";
    }
}

test "caching issue" {
    test_cases = [(10, True), (11, False)];
    # Write the generated test into an isolated temp dir so it never pollutes
    # the source tree and parallel worker runs cannot collide.
    with tempfile.TemporaryDirectory() as tmpdir {
        test_file = os.path.join(tmpdir, "test_caching_issue.jac");
        for (x, is_passed) in test_cases {
            with open(test_file, "w") as f {
                f.write(f'test "mytest" {{\n    assert 10 == {x};\n}}\n');
            }
            process = subprocess.Popen(
                ["jac", "test", test_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            );
            (stdout, stderr) = process.communicate();
            combined = stdout + stderr;
            # the rebuilt file must re-run (not
            # serve a stale cached result), so pass/fail flips with the assertion.
            if is_passed {
                assert "1 passed" in combined;
            } else {
                assert "1 failed" in combined;
            }
        }
    }
}

test "run jac name py" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("py_run.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout = captured.getvalue();
    assert "Hello, World!" in stdout;
    assert "Sum: 8" in stdout;
}

test "jac run py bugs" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("jac_run_py_bugs.py"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout = captured.getvalue();
    assert "Hello, my name is Alice and I am 30 years old." in stdout;
    assert "MyModule initialized!" in stdout;
}

test "cli defaults to run with file" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.run(fixture_path("hello.jac"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout = captured.getvalue();
    assert "Hello World!" in stdout;
}

test "cli implicit run passes through flags before filename" {
    process = subprocess.Popen(
        ["jac", "--no-cache", fixture_path("hello.jac")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    );
    (stdout, stderr) = process.communicate();
    assert process.returncode == 0 , f"Expected exit 0, got {process.returncode}: {stderr}";
    assert "Hello World!" in stdout;
}

test "cli error exit codes" {
    # Test run command with syntax error
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = execution.run(fixture_path("err2.jac"));
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 1 , "run command should exit with code 1 on syntax error";
    assert "Error" in stderr;

    # Test check command with syntax error
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = analysis.check([fixture_path("err2.jac")]);
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 1 , "check command should exit with code 1 on type check error";

    # Test format command with file that needs changes
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False
    ) as temp_file {
        temp_file.write('with entry{print("hello");}');
        temp_path = temp_file.name;
    }
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = analysis.format([temp_path]);
        } finally {
            sys.stdout = old_stdout;
        }
        assert result == 1 , (
            "format command should exit with code 1 when file is changed"
        );
    } finally {
        os.remove(temp_path);
    }

    # Test check command with invalid file type
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = analysis.check(["/nonexistent.txt"]);
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 1 , "check command should exit with code 1 on invalid file type";
    assert "is not a .jac file" in stderr;

    # Test tool command with non-existent tool
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = tools.tool("nonexistent_tool");
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 1 , "tool command should exit with code 1 on non-existent tool";
    assert "not found" in stderr;

    # Test successful run returns exit code 0
    # Clear stale errors from previous sub-tests so only hello.jac's
    # own diagnostics affect the exit code.
    _rt = __import__("jaclang.runtime.runtime", fromlist=["JacRuntime"]);
    _rt.JacRuntime.program.errors_had.clear();
    _rt.JacRuntime.program.warnings_had.clear();
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = execution.run(fixture_path("hello.jac"));
    } finally {
        sys.stdout = old_stdout;
    }
    stdout = captured.getvalue();
    assert result == 0 , "run command should exit with code 0 on success";
    assert "Hello World!" in stdout;
}

test "format tracks changed files" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Create a file that needs formatting (bad indentation/spacing)
        needs_formatting = os.path.join(tmpdir, "needs_format.jac");
        with open(needs_formatting, "w") as f {
            f.write('with entry{print("hello");}');
        }
        # Create a file that is already formatted
        already_formatted = os.path.join(tmpdir, "already_formatted.jac");
        with open(already_formatted, "w") as f {
            f.write('with entry {\n    print("hello");\n}\n');
        }
        # Run format on the directory
        captured_stderr = io.StringIO();
        old_stderr = sys.stderr;
        sys.stderr = captured_stderr;
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = analysis.format([tmpdir]);
            stdout = captured.getvalue();
            stderr = captured_stderr.getvalue();
        } finally {
            sys.stdout = old_stdout;
            sys.stderr = old_stderr;
        }
        # Exit code 1 indicates files were changed (useful for pre-commit hooks)
        assert result == 1;
        # Output may go to stdout or stderr depending on console implementation
        combined_output = stdout + stderr;
        assert "2/2" in combined_output;
        assert "(1 changed)" in combined_output;
    }
}

test "format -s preserves bracketed Jac syntax through Rich console" {
    # Regression: `jac format -s` prints formatted source via `console.print`.
    # The built-in Rich-style console — what real users see when they run the
    # `jac` CLI — must emit bracketed Jac syntax like `[root-->]` or
    # `todos + [t]` verbatim; it looks like terminal markup but the console
    # never interprets markup/highlight in caller data. This test invokes the
    # `jac` binary via subprocess so the full CLI console + stdout path is
    # exercised end-to-end (calling `analysis.format` from inside the suite covers
    # the same console but not the real CLI stdout path).
    with tempfile.TemporaryDirectory() as tmpdir {
        src_path = os.path.join(tmpdir, "brackets.jac");
        # Deliberately unformatted so --to_screen has something to print.
        src = (
            "node Todo { has title: str; }\n"
            "with entry {\n"
            "    t: Todo = Todo(title=\"x\");\n"
            "    todos: list[Todo] = [];\n"
            "    todos = todos + [t];\n"
            "    ancestors = [root-->];\n"
            "}\n"
        );
        with open(src_path, "w") as f {
            f.write(src);
        }
        process = subprocess.Popen(
            ["jac", "fmt", "-s", src_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );
        (stdout, stderr) = process.communicate();
        combined = stdout + stderr;
        # Both bracket forms must appear verbatim in the -s output. If Rich
        # markup interpretation ever leaks back in, these get stripped
        # (producing `todos = todos + ;` and `ancestors = ;`) and this test
        # fails loudly.
        assert "[root-->]" in combined , (
            f"edge-walk literal was stripped by Rich markup parser:\n{combined}"
        );
        assert "+ [t]" in combined , (
            f"list literal RHS was stripped by Rich markup parser:\n{combined}"
        );
        # Sanity check: the file on disk must be unchanged under --to_screen.
        with open(src_path) as f {
            assert f.read() == src , (
                "jac format -s must not write back to the source file"
            );
        }
    }
}

test "format preserves file on syntax error" {
    with tempfile.TemporaryDirectory() as tmpdir {
        broken_file = os.path.join(tmpdir, "broken.jac");
        original_content = 'can foo() -> {{\n    print("broken syntax;\n}\n';
        with open(broken_file, "w") as f {
            f.write(original_content);
        }
        captured_stderr = io.StringIO();
        old_stderr = sys.stderr;
        sys.stderr = captured_stderr;
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            analysis.format([broken_file]);
        } finally {
            sys.stdout = old_stdout;
            sys.stderr = old_stderr;
        }
        with open(broken_file) as f {
            assert f.read() == original_content , (
                "jac format should not modify a file with syntax errors"
            );
        }
    }
}

test "format prints error messages and summary for syntax error file" {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        result = analysis.format([fixture_path("test_syntax_err.jac")]);
        stdout = captured_stdout.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    combined = stdout + stderr;

    # Should exit with code 1 (syntax errors fail the command)
    assert result == 1 , "format should exit with code 1 for syntax error file";

    # Should show FAILURES section header
    assert "FAILURES" in combined , "should display FAILURES section for syntax errors";

    # Failed file path should appear in the FAILURES section
    assert "test_syntax_err.jac" in combined , "should show file path in FAILURES section";

    # Actual syntax error messages should appear in stderr
    assert len(stderr.strip()) > 0 , "should print syntax error messages to stderr";

    # failed files summary section should appear
    assert "failed files" in combined , "should display failed files summary";

    # Summary line should mention error count
    assert "error" in combined , "should show error count in failed files summary";
}

test "format --lintfix preserves file on parse error" {
    with tempfile.TemporaryDirectory() as tmpdir {
        test_file = os.path.join(tmpdir, "parse_error.jac");
        # Parse error: 'can' without 'with' (should be 'def' for function-style)
        original_content = 'obj User {\n    can say_name() {\n        print("hi");\n    }\n}\n';
        with open(test_file, "w") as f {
            f.write(original_content);
        }
        captured_stderr = io.StringIO();
        old_stderr = sys.stderr;
        sys.stderr = captured_stderr;
        try {
            analysis.format([test_file], lintfix=True);
        } finally {
            sys.stderr = old_stderr;
        }
        with open(test_file) as f {
            actual_content = f.read();
            assert actual_content == original_content , (
                f"format --lintfix deleted/modified file with parse error. "
                f"Expected: {repr(original_content)}, Got: {repr(actual_content)}"
            );
        }
    }
}

test "jac create and run no root files" {
    _ensure_template_registry();
    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(_tmpdir);
    try {
        project_name = "test-no-root-files";
        project_path = Path(_tmpdir) / project_name;

        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = project.create(project_name);
        } finally {
            sys.stdout = old_stdout;
        }
        assert result == 0 , "jac create failed";

        # Record files after create (before run)
        # Get files/dirs in project root, excluding .jac directory.
        def get_root_files(path: Path) -> set {
            items = set();
            for item in path.iterdir() {
                if item.name != ".jac" {
                    items.add(item.name);
                }
            }
            return items;
        }

        files_before_run = get_root_files(project_path);

        # The cli scaffold dispatches argparse subcommands, so a bare run is
        # a usage error; `jac run main.jac -- greet <name>` is the happy path.
        # The template ends in sys.`exit(main()), which surfaces as SystemExit.
        os.chdir(project_path);
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        saved_argv = list(sys.argv);
        try {
            result = execution.run("main.jac", args=["greet", project_name]);
        } except SystemExit as e {
            result = int(e.code or 0);
        } finally {
            sys.stdout = old_stdout;
            sys.argv = saved_argv;
        }
        stdout = captured.getvalue();

        assert result == 0 , f"jac run failed: {stdout}";
        assert f"Hello, {project_name}! This is {project_name}." in stdout , stdout;

        # Record files after run
        files_after_run = get_root_files(project_path);

        # Check no new files were created in project root
        new_files = files_after_run - files_before_run;
        assert not new_files , (
            f"jac run created unexpected files in project root: {new_files}. "
            "All runtime files should be in .jac/ directory."
        );
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "jac create without name initializes current directory" {
    _ensure_template_registry();
    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(_tmpdir);
    try {
        cli_dir = Path(_tmpdir);
        dir_name = cli_dir.name;
        assert project.create() == 0;
        assert (cli_dir / "jac.toml").is_file();
        assert (cli_dir / "main.jac").is_file();
        assert not (cli_dir / "jactastic").exists();
        toml = (cli_dir / "jac.toml").read_text(encoding="utf-8");
        assert f'name = "{dir_name}"' in toml;

        # Second create in same directory should fail without --force
        assert project.create() != 0;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "install editable outside any project errors" {
    # Editable installs land in the CURRENT project's .jac/venv, so they require a
    # consuming project; running from a directory with no jac.toml must error
    # rather than fall back to a binary-global/host install target.
    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    try {
        pkg_dir = (Path(_tmpdir) / "my-lib").resolve();
        pkg_dir.mkdir();
        (pkg_dir / "jac.toml").write_text(
            '[project]\nname = "my-lib"\nversion = "0.1.0"\ndescription = "Test lib"\nentry-point = "main.jac"\n'
        );
        # cwd (_tmpdir) has no jac.toml of its own; clear any cached config from a
        # prior test so discovery actually runs against this project-less cwd.
        os.chdir(_tmpdir);
        _reset_config();
        result = project.install(editable=[[str(pkg_dir)]]);
        assert result == 1 , f"Expected error exit (no project), got {result}";
    } finally {
        _reset_config();
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "install editable resolves config from cwd when given dot path" {
    import from unittest.mock { patch }

    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    try {
        resolved_tmpdir = Path(_tmpdir).resolve();
        (resolved_tmpdir / "jac.toml").write_text(
            '[project]\nname = "dot-lib"\nversion = "0.1.0"\ndescription = "Test lib"\nentry-point = "main.jac"\n'
        );
        os.chdir(_tmpdir);

        captured_src_dir = [];
        def fake_install_editable(self: object, src_dir: object, site_pkgs: object) {
            captured_src_dir.append(src_dir);
        }

        with patch(
            "jaclang.dist.publish.builder.WheelBuilder.install_editable",
            fake_install_editable
        ) {
            result = project.install(editable=[["."]]);
        }

        assert result == 0 , f"Expected success, got exit code {result}";
        assert len(captured_src_dir) == 1 , "install_editable should be called once";
        assert captured_src_dir[0] == resolved_tmpdir , (
            f"Expected src_dir={resolved_tmpdir}, got {captured_src_dir[0]}"
        );
    } finally {
        _reset_config();
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "jac install -e accepts space-separated and repeated flag forms" {
    _tmpdir = tempfile.mkdtemp();
    try {
        pkg_a = (Path(_tmpdir) / "pkg-a").resolve();
        pkg_b = (Path(_tmpdir) / "pkg-b").resolve();
        pkg_c = (Path(_tmpdir) / "pkg-c").resolve();
        pkg_a.mkdir();
        pkg_b.mkdir();
        pkg_c.mkdir();
        (pkg_a / "jac.toml").write_text(
            '[project]\nname = "pkg-a"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        (pkg_b / "jac.toml").write_text(
            '[project]\nname = "pkg-b"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        (pkg_c / "jac.toml").write_text(
            '[project]\nname = "pkg-c"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        # The host project (cwd) receives the editable links in its .jac/venv.
        (Path(_tmpdir) / "jac.toml").write_text(
            '[project]\nname = "host"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );

        # -e pkg_a pkg_b exercises space-separated; -e pkg_c exercises repeated flag
        process = subprocess.Popen(
            [
                "jac",
                "install",
                "-e",
                str(pkg_a),
                str(pkg_b),
                "-e",
                str(pkg_c),
                "--dry-run"
            ],
            cwd=_tmpdir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );
        (stdout, stderr) = process.communicate();
        combined = stdout + stderr;

        assert process.returncode == 0 , (
            f"Expected exit 0, got {process.returncode}.\n{combined}"
        );
        assert "pkg-a" in combined , f"pkg-a not mentioned in output:\n{combined}";
        assert "pkg-b" in combined , f"pkg-b not mentioned in output:\n{combined}";
        assert "pkg-c" in combined , f"pkg-c not mentioned in output:\n{combined}";
    } finally {
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "jac install -e links all packages for space-separated and repeated flag forms" {
    import from unittest.mock { patch }

    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    try {
        pkg_a = (Path(_tmpdir) / "pkg-a").resolve();
        pkg_b = (Path(_tmpdir) / "pkg-b").resolve();
        pkg_c = (Path(_tmpdir) / "pkg-c").resolve();
        pkg_a.mkdir();
        pkg_b.mkdir();
        pkg_c.mkdir();
        (pkg_a / "jac.toml").write_text(
            '[project]\nname = "pkg-a"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        (pkg_b / "jac.toml").write_text(
            '[project]\nname = "pkg-b"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        (pkg_c / "jac.toml").write_text(
            '[project]\nname = "pkg-c"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        # The host project (cwd) receives the editable links in its .jac/venv.
        (Path(_tmpdir) / "jac.toml").write_text(
            '[project]\nname = "host"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        os.chdir(_tmpdir);

        linked: list = [];
        def fake_install_editable(self: object, src_dir: object, site_pkgs: object) {
            linked.append(src_dir);
        }

        with patch(
            "jaclang.dist.publish.builder.WheelBuilder.install_editable",
            fake_install_editable
        ) {
            # [[pkg_a, pkg_b], [pkg_c]] mirrors: -e pkg_a pkg_b -e pkg_c
            result = project.install(editable=[[str(pkg_a), str(pkg_b)], [str(pkg_c)]]);
        }

        assert result == 0 , f"Expected exit 0, got {result}";
        assert len(linked) == 3 , f"Expected install_editable called 3 times, got {len(
            linked
        )}";
        assert pkg_a in linked , f"pkg-a not linked; linked={linked}";
        assert pkg_b in linked , f"pkg-b not linked; linked={linked}";
        assert pkg_c in linked , f"pkg-c not linked; linked={linked}";
    } finally {
        _reset_config();
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "jac install <pkg> routes package names to the project venv installer" {
    # Verifies CLI wiring: positional args map into `packages` and are installed
    # into the current project's venv. install_specs is patched so the test
    # touches neither the network nor a real venv.
    import from unittest.mock { patch }

    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    try {
        (Path(_tmpdir) / "jac.toml").write_text(
            '[project]\nname = "host"\nversion = "0.1.0"\ndescription = ""\nentry-point = "main.jac"\n'
        );
        os.chdir(_tmpdir);
        # `install` now records to jac.toml, so discovery must resolve to this
        # tmp project (not a config cached from an earlier test) before save.
        _reset_config();
        captured: list = [];
        def fake_install_specs(
            self: object, config: object, specs: object, ctx: object
        ) -> bool {
            captured.append(specs);
            return True;
        }
        with patch(
            "jaclang.project.providers.PythonProvider.install_specs", fake_install_specs
        ) {
            result = project.install(packages=["numpy", "pandas"]);
        }
        assert result == 0 , f"Expected exit 0, got {result}";
        assert captured == [["numpy", "pandas"]] , f"unexpected specs routed: {captured}";
    } finally {
        _reset_config();
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "jac install <pkg> outside a project errors" {
    # `jac install <pkg>` targets the project venv, so it requires a project.
    with tempfile.TemporaryDirectory() as tmp {
        result = subprocess.run(
            ["jac", "install", "numpy", "--dry-run"],
            capture_output=True,
            text=True,
            cwd=str(tmp)
        );
        combined = result.stdout + result.stderr;
        assert result.returncode == 1 , f"Expected exit 1 (no project):\n{combined}";
        assert "No jac.toml found" in combined , f"Expected hint about missing project:\n{combined}";
    }
}

# --- TestConfigCommand tests ---
test "config groups" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="groups");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "project" in stdout;
        assert "run" in stdout;
        assert "build" in stdout;
        assert "test" in stdout;
        assert "serve" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config path" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="path");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "jac.toml" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config show" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="show");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "test-project" in stdout;
        assert "1.0.0" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config show group" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="show", group="project");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "test-project" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config list" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="list");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "project" in stdout or "name" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config get" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="get", key="project.name");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "test-project" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config set and unset" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        # Set a new value
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(
                action="set", key="project.description", value="Updated desc"
            );
        } finally {
            sys.stdout = old_stdout;
        }
        assert result == 0;

        # Verify the value was set
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="get", key="project.description");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert "Updated desc" in stdout;

        # Unset the value
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="unset", key="project.description");
        } finally {
            sys.stdout = old_stdout;
        }
        assert result == 0;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config output json" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="show", output="json");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        data = json.loads(stdout);
        assert isinstance(data, dict);
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config output toml" {
    tmp_path = tempfile.mkdtemp();
    toml_content = '[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "A test project"\n\n[run]\ncache = false\n\n[build]\ntypecheck = true\n\n[test]\nverbose = true\n';
    toml_path = os.path.join(tmp_path, "jac.toml");
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    set_config(None);
    try {
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = config_cmd.config(action="show", output="toml");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert result == 0;
        assert "[" in stdout;
    } finally {
        os.chdir(original_cwd);
        set_config(None);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

test "config no project" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        captured_out = io.StringIO();
        captured_err = io.StringIO();
        old_stdout = sys.stdout;
        old_stderr = sys.stderr;
        sys.stdout = captured_out;
        sys.stderr = captured_err;
        try {
            config_cmd.config(action="path");
        } finally {
            sys.stdout = old_stdout;
            sys.stderr = old_stderr;
        }
        combined = captured_out.getvalue() + captured_err.getvalue();
        assert "jac.toml" in combined;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}

# --- TestCleanCommand tests ---
test "clean no project" {
    with tempfile.TemporaryDirectory() as tmpdir {
        original_cwd = os.getcwd();
        os.chdir(tmpdir);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(force=True);
            stderr = captured_stderr.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 1;
        assert "No jac.toml found" in stderr;
    }
}

test "clean nothing to clean" {
    with tempfile.TemporaryDirectory() as tmpdir {
        project_path = _create_clean_project(tmpdir);
        # Remove the .jac/data directory if it exists
        data_dir = os.path.join(project_path, ".jac", "data");
        if os.path.exists(data_dir) {
            shutil.rmtree(data_dir);
        }
        original_cwd = os.getcwd();
        os.chdir(project_path);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(force=True);
            stdout = captured_stdout.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 0;
        assert "Nothing to clean" in stdout;
    }
}

test "clean data directory" {
    with tempfile.TemporaryDirectory() as tmpdir {
        project_path = _create_clean_project(tmpdir);
        # Create .jac/data directory with some files
        data_dir = os.path.join(project_path, ".jac", "data");
        os.makedirs(data_dir, exist_ok=True);
        test_file = os.path.join(data_dir, "test.db");
        with open(test_file, "w") as f {
            f.write("test data");
        }
        assert os.path.exists(data_dir);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(force=True);
            stdout = captured_stdout.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 0;
        assert "Removed data:" in stdout;
        assert not os.path.exists(data_dir);
    }
}

test "clean cache directory" {
    with tempfile.TemporaryDirectory() as tmpdir {
        project_path = _create_clean_project(tmpdir);
        cache_dir = os.path.join(project_path, ".jac", "cache");
        os.makedirs(cache_dir, exist_ok=True);
        test_file = os.path.join(cache_dir, "cached.pyc");
        with open(test_file, "w") as f {
            f.write("cached bytecode");
        }
        assert os.path.exists(cache_dir);
        original_cwd = os.getcwd();
        os.chdir(project_path);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(cache=True, force=True);
            stdout = captured_stdout.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 0;
        assert "Removed cache:" in stdout;
        assert not os.path.exists(cache_dir);
    }
}

test "clean all directories" {
    with tempfile.TemporaryDirectory() as tmpdir {
        project_path = _create_clean_project(tmpdir);
        # Create all .jac subdirectories with content
        jac_dir = os.path.join(project_path, ".jac");
        dirs_to_create = ["data", "cache", "venv", "client"];
        for dir_name in dirs_to_create {
            dir_path = os.path.join(jac_dir, dir_name);
            os.makedirs(dir_path, exist_ok=True);
            with open(os.path.join(dir_path, "test.txt"), "w") as f {
                f.write("test");
            }
        }
        for dir_name in dirs_to_create {
            assert os.path.exists(os.path.join(jac_dir, dir_name));
        }
        original_cwd = os.getcwd();
        os.chdir(project_path);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(**{"all": True, "force": True});
            stdout = captured_stdout.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 0;
        assert "Clean completed successfully" in stdout;
        # Verify all directories are removed
        for dir_name in dirs_to_create {
            assert not os.path.exists(os.path.join(jac_dir, dir_name));
        }
    }
}

test "clean multiple specific directories" {
    with tempfile.TemporaryDirectory() as tmpdir {
        project_path = _create_clean_project(tmpdir);
        # Create .jac subdirectories with content
        jac_dir = os.path.join(project_path, ".jac");
        data_dir = os.path.join(jac_dir, "data");
        cache_dir = os.path.join(jac_dir, "cache");
        venv_dir = os.path.join(jac_dir, "venv");
        for dir_path in [data_dir, cache_dir, venv_dir] {
            os.makedirs(dir_path, exist_ok=True);
            with open(os.path.join(dir_path, "test.txt"), "w") as f {
                f.write("test");
            }
        }
        original_cwd = os.getcwd();
        os.chdir(project_path);
        _reset_config();
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        try {
            result = project.clean(data=True, cache=True, force=True);
            stdout = captured_stdout.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            os.chdir(original_cwd);
            _reset_config();
        }
        assert result == 0;
        assert "Removed data:" in stdout;
        assert "Removed cache:" in stdout;
        # Venv should NOT be removed
        assert os.path.exists(venv_dir);
        assert not os.path.exists(data_dir);
        assert not os.path.exists(cache_dir);
    }
}

test "error traceback shows source code" {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        result = execution.run(fixture_path("import_error_traceback.jac"));
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    # Should exit with error
    assert result == 1 , "run command should exit with code 1 on import error";

    # Should show the error message
    assert "Error" in stderr , "stderr should contain Error";
    assert (
        "No module named" in stderr
        or "ImportError" in stderr
        or "ModuleNotFoundError" in stderr
    ) , "stderr should contain import error message";

    # Should show the source code line that caused the error
    assert "import from jac_nonexistent_module" in stderr , (
        "stderr should show the problematic import statement"
    );

    # Should show the file path and line number
    assert "import_error_traceback.jac" in stderr , (
        "stderr should contain the source file name"
    );
    assert ":7" in stderr or "line 7" in stderr , (
        "stderr should indicate line number 7 where the error occurred"
    );
}

test "syntax error pretty print" {
    import from jaclang.compiler.driver.program { JacProgram }

    program = JacProgram();
    program.compile(fixture_path("test_syntax_err.jac"));
    # The trailing string before '}' is a semicolon-less tail expression
    # (implicit return), so the 'print "..."' juncture is a syntax error
    # alongside the 'can'-signature error; with checking on the critical
    # path the recovered tree also reports its missing return annotation.
    assert len(program.errors_had) == 3 , (
        f"Expected 3 errors with improved error reporting, got {len(
            program.errors_had
        )}"
    );
    _assert_error_pretty_found(
        """
        2 |
        3 | walker w {
        4 |     can foo {
          |
    """,
        program.errors_had[0].pretty_print()
    );
    _assert_error_pretty_found("Missing ';'", program.errors_had[1].pretty_print());
}

test "jac grammar" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = analysis.grammar();
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert result == 0 , "grammar command should exit with code 0";
    assert "::=" in stdout_value , "EBNF output should contain rule definitions";
    assert "module" in stdout_value , "Grammar should contain module rule";
}

test "jac cli check ignore patterns" {
    test_dir = fixture_path("deep");
    result_count = _run_jac_check(
        test_dir, ["deeper", "one_lev_dup.jac", "one_lev.jac", "mycode"]
    );
    assert result_count == 1;
}

"""Test --ignore with multiple wildcard patterns."""
test "jac cli check ignore with wildcards" {
    test_dir = fixture_path("deep");
    result_count = _run_jac_check(test_dir, ["one_lev*", "snd_*"]);
    assert result_count == 3;
}

test "jac check shows warnings for files with warnings only" {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        result = analysis.check([fixture_path("warnings_only.jac")]);
        stdout = captured_stdout.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    combined = stdout + stderr;

    # Should exit with code 0 (warnings don't fail the check)
    assert result == 0 , "check should exit with code 0 for warnings only";

    # Should show FAILURES section with warnings
    assert "FAILURES" in combined , "should display FAILURES section for warnings";

    # Should show the warning messages
    assert "defined but never used" in combined , "should display unused variable warnings";

    # Should show warning indicators
    assert "warning" in combined.lower() , "should indicate warnings in output";

    # File should appear in summary with warnings count
    assert "warnings_only.jac" in combined , "should show file path in output";
}

test "jac check nowarn flag suppresses warnings" {
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        result = analysis.check([fixture_path("warnings_only.jac")], nowarn=True);
        stdout = captured_stdout.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    combined = stdout + stderr;

    # Should still exit with code 0
    assert result == 0 , "check should exit with code 0 when warnings are suppressed";

    # Should show ok status
    assert "ok" in combined , "should show ok when warnings are suppressed";

    # Should NOT show detailed warning messages
    assert "defined but never used" not in combined , "should not display warning details when nowarn=True";
}

"""Run analysis.check with captured stdout/stderr; reset global config after."""
def _check_captured(
    paths: list, disable_error_code: (list | None) = None
) -> tuple[int, str] {
    (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
    _reset_config();
    try {
        result = analysis.check(paths, disable_error_code=disable_error_code or []);
        combined = captured_stdout.getvalue() + captured_stderr.getvalue();
        return (result, combined);
    } finally {
        _restore_output(old_stdout, old_stderr);
        set_config(None);
        _reset_config();
    }
}

test "jac check disable_error_code maps to check arg" {
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.cli.manifest_parse { build_command_parser }
    check_meta = get_command_meta("check");
    assert check_meta is not None;
    parser = build_command_parser(check_meta);
    (args, _) = parser.parse_known_args(
        [fixture_path("warnings_only.jac"), "--disable-error-code", "E1030"]
    );
    assert args.disable_error_code == ["E1030"] , (
        "kebab-case CLI flag should map to disable_error_code arg"
    );
}

test "jac check disable_error_code resolves kebab alias and comma tokens" {
    (resolved, unknown) = resolve_diagnostic_tokens(
        ["no-print", "E1030,W2001", "e9999", "E9999"]
    );
    assert resolved == ["E3012", "E1030", "W2001"] , (
        "kebab aliases and comma-separated codes should resolve"
    );
    assert unknown == ["E9999"] , ("unknown tokens should dedupe by canonical code");
}

test "jac check disable_error_code suppresses matching diagnostics" {
    fixture = fixture_path("check_disable_error_code_e1030.jac");
    (base_result, _) = _check_captured([fixture]);
    assert base_result == 1 , "fixture should fail check without suppression";
    (suppressed_result, suppressed_output) = _check_captured(
        [fixture], disable_error_code=["E1030"]
    );
    assert suppressed_result == 0 , "suppressed E1030 should not fail check";
    assert "FAILED" not in suppressed_output , "suppressed run should not fail";
}

test "jac check disable_error_code comma form suppresses diagnostics" {
    fixture = fixture_path("check_disable_error_code_e1030.jac");
    (result, output) = _check_captured([fixture], disable_error_code=["E1030,E9999"]);
    assert result == 0 , "comma-separated E1030 should suppress the fixture error";
    assert "FAILED" not in output , "suppressed comma-form run should not fail";
    assert "Ignoring unknown diagnostic codes in --disable-error-code" in output , (
        "unknown comma chunk member should still warn"
    );
}

test "jac check disable_error_code warns on unknown diagnostics" {
    fixture = fixture_path("check_disable_error_code_e1030.jac");
    (_, combined) = _check_captured([fixture], disable_error_code=["E9999", "E1030"]);
    assert "Ignoring unknown diagnostic codes in --disable-error-code" in combined , (
        "unknown codes should produce an explicit warning"
    );
    assert "E9999" in combined , "unknown warning should use canonical code casing";
}

test "jac check native-coverage flag maps to check arg" {
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.cli.manifest_parse { build_command_parser }
    check_meta = get_command_meta("check");
    assert check_meta is not None;
    parser = build_command_parser(check_meta);
    (args, _) = parser.parse_known_args(
        [fixture_path("warnings_only.jac"), "--native-coverage"]
    );
    assert getattr(args, "native_coverage", False) == True , (
        "kebab flag should map to native_coverage dest"
    );
}

test "jac check native coverage ranks module outcomes" {
    with tempfile.TemporaryDirectory() as td {
        with open(os.path.join(td, "pure.jac"), "w") as f {
            f.write("def add(a: int, b: int) -> int {\n    return a + b;\n}\n");
        }
        with open(os.path.join(td, "demote.jac"), "w") as f {
            f.write(
                "obj Widget {\n    has size: int = 0;\n\n    def render -> str {\n"
                    + "        return \"ok\";\n    }\n}\n\ndef build -> str {\n"
                    + "    w: any = Widget();\n    return w.render();\n}\n"
            );
        }
        with open(os.path.join(td, "blocked.jac"), "w") as f {
            f.write(
                "node Item {\n    has label: str = \"\";\n}\n\n"
                    + "def pin(label: str) -> int {\n    root ++> Item(label=label);\n"
                    + "    return 1;\n}\n"
            );
        }
        (captured_stdout, captured_stderr, old_stdout, old_stderr) = _capture_output();
        _reset_config();
        try {
            result = analysis.check([td], native_coverage=True);
            combined = captured_stdout.getvalue() + captured_stderr.getvalue();
        } finally {
            _restore_output(old_stdout, old_stderr);
            set_config(None);
            _reset_config();
        }
        assert "native coverage" in combined.lower() , "coverage header missing";
        assert "native seams" in combined , (
            "a module whose callable demoted granularly must be reported "
            "under the native-seams section"
        );
        assert "E5092" in combined , (
            "the seam reason must carry the first error code"
        );
        assert "build: " in combined , ("the seam must name the demoted callable");
        assert "demote.jac" in combined , "seamed module path missing";
        assert "blocked.jac" in combined , "server module path missing";
        assert "pure.jac" in combined , "native module path missing";
        assert "root access (persistent graph)" in combined , (
            "server reason strings must be real signal labels"
        );
        assert result == 0 , "coverage seams must not flip exit code";
    }
}

test "lexer does not hang on unterminated jsx" {
    # BUG: Unterminated JSX (e.g. `<div>hello` with no closing tag)
    # hits EOF while the lexer is still in JSX_CONTENT mode.
    # scan_jsx_content returns ERROR without popping the mode or
    # producing EOF, so tokenize() looped forever. The stuck detector
    # now forces EOF when the lexer stops advancing.
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = execution.run(fixture_path("jsx_unterminated_hang.jac"));
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 1 , "should exit with error code 1, not hang";
    assert "Error" in stderr , "should report parse errors to stderr";
}

test "bare lt in jsx content is treated as text" {
    # A `<` not followed by alpha, `/`, or `>` (e.g. `<--`) should be
    # consumed as JSX text, not mistaken for a tag opener. Previously
    # the text loop broke on every `<`, and when no JSX pattern matched
    # the lexer never advanced — causing an infinite loop.
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = execution.run(fixture_path("jsx_bare_lt_in_content.jac"));
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert result == 0 , f"should compile successfully, got errors: {stderr}";
}

test "jac check reports errors for files inside jaclang source tree" {
    # Regression: the self-host redirect routed jaclang-internal files to
    # the self-host program, so errors were invisible to the caller's JacProgram.
    # force_target_program=True (set by jac check) fixes this. The fixture
    # is deliberately ill-typed so this test never depends on an incidental
    # compiler bug in a shared fixture.
    internal_fixture = os.path.join(
        JAC_ROOT, "jaclang", "compiler", "tests", "fixtures", "always_type_error.jac"
    );
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        result = analysis.check([internal_fixture]);
        stdout = captured_stdout.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    combined = stdout + stderr;

    # always_type_error.jac is deliberately ill-typed — check must report
    # its errors even though the file lives inside the jaclang package.
    assert result == 1 , (
        "jac check should report errors for jaclang-internal files, "
        f"but returned exit code {result}. Output:\n{combined}"
    );
    assert "failed" in combined.lower() , (
        "Expected failure output for jaclang-internal file with type errors"
    );
}

"""Regression: JIR cache must preserve Archetype.body for generic type inference."""
test "generic type inference is identical across fresh processes" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        with open(os.path.join(tmpdir, "lib.jac"), "w") as f {
            f.write("obj Box[T] { has value: T; def get -> T { return self.value; } }");
        }
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                "import from lib { Box }\nwith entry { print(Box(value=42).get() + 1); }"
            );
        }
        main_path = os.path.join(tmpdir, "main.jac");
        # Run check twice: first creates cache, second uses it
        outputs: list[str] = [];
        for _ in range(2) {
            JacRuntime.program = JacProgram();
            (cap_out, cap_err, old_out, old_err) = _capture_output();
            try {
                analysis.check([main_path]);
                outputs.append(cap_out.getvalue() + cap_err.getvalue());
            } finally {
                _restore_output(old_out, old_err);
            }
        }
        # E1055 appears if Box[int].get() returns Unknown due to lost type info
        assert "No matching overload" not in outputs[1] , f"JIR cache lost type info:\n{outputs[
            1
        ]}";
    }
}

"""Regression: JIR cache must preserve IndexSlice.slices (Slice is a UniNode).

IndexSlice.Slice was previously a plain inner class without a node ID, so the
JIR writer serialised the slices field as EXTERNAL_REF, reader discarded it,
slices=[] on cache hit, list iteration type became Unknown.
"""
test "list iteration type through IndexSlice is identical across runs" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                "import from jaclang.runtime.archetype { NodeAnchor }\n"
                "def check_iter(na: NodeAnchor) -> None {\n"
                "    for a in na.edges { aid = a.id; }\n"
                "}\n"
            );
        }
        main_path = os.path.join(tmpdir, "main.jac");
        # Run check twice: first creates cache, second uses it
        outputs: list[str] = [];
        for _ in range(2) {
            JacRuntime.program = JacProgram();
            (cap_out, cap_err, old_out, old_err) = _capture_output();
            try {
                analysis.check([main_path]);
                outputs.append(cap_out.getvalue() + cap_err.getvalue());
            } finally {
                _restore_output(old_out, old_err);
            }
        }
        # E1032 appears if anchor type becomes Unknown on the cached run
        assert "Type is Unknown" not in outputs[1] , f"JIR cache lost IndexSlice type info:\n{outputs[
            1
        ]}";
    }
}

"""Regression: JIR cache must preserve impl-defined instance variables.

Instance variables defined in impl files (e.g., self.x in __init__) are added to
the archetype's symbol table by DeclImplMatchPass._populate_self_member_symbols.
Since impl_mod is not serialized in JIR, these symbols were lost on cache reload.
"""
test "impl defined instance variables resolve identically across runs" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        # Create a class with __init__ declared in .jac, implemented in .impl.jac
        with open(os.path.join(tmpdir, "myclass.jac"), "w") as f {
            f.write(
                "class Foo {\n    def init(val: int);\n    def get_val -> int { return self.value; }\n}\n"
            );
        }
        with open(os.path.join(tmpdir, "myclass.impl.jac"), "w") as f {
            f.write("impl Foo.init(val: int) { self.value = val; }\n");
        }
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                "import from myclass { Foo }\nwith entry { print(Foo(10).get_val()); }\n"
            );
        }
        main_path = os.path.join(tmpdir, "main.jac");
        # Run check twice: first creates cache, second uses it
        outputs: list[str] = [];
        for _ in range(2) {
            JacRuntime.program = JacProgram();
            (cap_out, cap_err, old_out, old_err) = _capture_output();
            try {
                analysis.check([main_path]);
                outputs.append(cap_out.getvalue() + cap_err.getvalue());
            } finally {
                _restore_output(old_out, old_err);
            }
        }
        # E1031 "has no attribute 'value'" appears if impl symbols lost on cache reload
        assert "has no attribute" not in outputs[1] , f"JIR cache lost impl-defined instance variable:\n{outputs[
            1
        ]}";
    }
}

"""Regression: JIR cache must compute MRO for subtype checking.

When a module is loaded from JIR cache, class types may have empty MRO lists.
The is_sub_class check must compute MRO on demand to properly recognize
subtype relationships (e.g., ClassType extends TypeBase).
"""
test "jir cache computes mro for subtype checking" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        # Create a module with base and derived classes
        with open(os.path.join(tmpdir, "types.jac"), "w") as f {
            f.write(
                "obj Base { has x: int = 0; }\n"
                "obj Derived(Base) { has y: int = 0; }\n"
            );
        }
        # Create main that uses Derived where Base is expected
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                "import from types { Base, Derived }\n"
                "def use_base(b: Base) -> int { return b.x; }\n"
                "with entry { print(use_base(Derived())); }\n"
            );
        }
        main_path = os.path.join(tmpdir, "main.jac");
        # Run check twice: first creates cache, second uses it
        outputs: list[str] = [];
        for _ in range(2) {
            JacRuntime.program = JacProgram();
            (cap_out, cap_err, old_out, old_err) = _capture_output();
            try {
                analysis.check([main_path]);
                outputs.append(cap_out.getvalue() + cap_err.getvalue());
            } finally {
                _restore_output(old_out, old_err);
            }
        }
        # E1053 "Cannot assign Derived to parameter 'b' of type Base" appears if MRO not computed
        assert "Cannot assign" not in outputs[1] , f"JIR cache lost MRO for subtype check:\n{outputs[
            1
        ]}";
    }
}

"""Regression: JIR cache must preserve HasVar.accessors None vs empty list.

A plain `has` field has accessors=None; a native property (`has x: T { getter; setter; }`)
has a non-empty accessors list. The accessors field is serialised as NODE_LIST, which
cannot distinguish None from [] -- both round-trip to []. On a cache hit a plain field's
accessors became [], so the property classifier saw a setter-less property and falsely
raised E1005 on assignment.
"""
test "field vs property accessor typing is identical across runs" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        # Box has a plain field `data` next to a native getter/setter property `value`.
        with open(os.path.join(tmpdir, "lib.jac"), "w") as f {
            f.write(
                "obj Box {\n"
                "    has data: int = 0,\n"
                "        _v: int = 0,\n"
                "        value: int {\n"
                "            getter { return self._v; }\n"
                "            setter(x: int) { self._v = x; }\n"
                "        }\n"
                "}\n"
            );
        }
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                "import from lib { Box }\n"
                "with entry { b = Box(); b.data = 5; print(b.data); }\n"
            );
        }
        main_path = os.path.join(tmpdir, "main.jac");
        # Run check twice: first creates cache, second uses it
        outputs: list[str] = [];
        for _ in range(2) {
            JacRuntime.program = JacProgram();
            (cap_out, cap_err, old_out, old_err) = _capture_output();
            try {
                analysis.check([main_path]);
                outputs.append(cap_out.getvalue() + cap_err.getvalue());
            } finally {
                _restore_output(old_out, old_err);
            }
        }
        # E1005 "read-only property" appears if accessors None->[] makes `data` look like a property
        assert "read-only property" not in outputs[1] , f"JIR cache lost plain-field accessors:\n{outputs[
            1
        ]}";
    }
}

"""jac check on .impl.jac files should compile the base file and filter errors."""
test "jac check on impl file redirects to base and filters errors" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        # Create a base .jac file with a type error in the base
        with open(os.path.join(tmpdir, "mymod.jac"), "w") as f {
            f.write(
                "def greet(name: str) -> str;\n"
                "def bad_base -> int { return 'not_int'; }\n"
            );
        }
        # Create an impl file with its own type error
        impl_dir = os.path.join(tmpdir, "impl");
        os.makedirs(impl_dir);
        with open(os.path.join(impl_dir, "mymod.impl.jac"), "w") as f {
            f.write("impl greet(name: str) -> str { return 42; }\n");
        }
        impl_path = os.path.join(impl_dir, "mymod.impl.jac");
        JacRuntime.program = JacProgram();
        (cap_out, cap_err, old_out, old_err) = _capture_output();
        try {
            result = analysis.check([impl_path]);
            output = cap_out.getvalue() + cap_err.getvalue();
        } finally {
            _restore_output(old_out, old_err);
        }
        # The impl file has a type error (returning int instead of str),
        # so check should report failure
        assert result == 1 , (
            f"Expected exit code 1 for impl file with errors, got {result}. "
            f"Output:\n{output}"
        );
        # Errors from the base file (bad_base) should NOT appear in output
        assert "bad_base" not in output , (
            f"Base file errors should be filtered out when checking impl file. "
            f"Output:\n{output}"
        );
    }
}

"""A directory walk skips annexes the base module in the same run already compiles."""
test "jac check directory skips covered annexes" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime }

    with tempfile.TemporaryDirectory() as tmpdir {
        with open(os.path.join(tmpdir, "mymod.jac"), "w") as f {
            f.write("def greet(name: str) -> str;\n");
        }
        impl_dir = os.path.join(tmpdir, "impl");
        os.makedirs(impl_dir);
        with open(os.path.join(impl_dir, "mymod.impl.jac"), "w") as f {
            f.write("impl greet(name: str) -> str { return name; }\n");
        }
        with open(os.path.join(tmpdir, "orphan.impl.jac"), "w") as f {
            f.write("impl nobase.thing { return 1; }\n");
        }
        JacRuntime.program = JacProgram();
        # mymod.jac plus the orphan annex no base module covers -- not
        # mymod.impl.jac, which compiling mymod.jac already folds in.
        assert _run_jac_check(tmpdir) == 2;
        JacRuntime.program = JacProgram();
        # An annex folder named directly is still walked.
        assert _run_jac_check(impl_dir) == 1;
        JacRuntime.program = JacProgram();
        # So is an annex named directly.
        assert _run_jac_check(os.path.join(impl_dir, "mymod.impl.jac")) == 1;
    }
}

# ===== install --extras CLI tests =====
glob _EXTRAS_JAC_TOML = (
         '[project]\nname = "mypkg"\nversion = "0.1.0"\n\n'
         '[dependencies]\n\n'
         '[optional-dependencies.data]\npymongo = ">=4.0,<5.0"\nredis = ">=7.0,<8.0"\n\n'
         '[optional-dependencies.monitoring]\nprometheus-client = ">=0.21.0,<1.0.0"\n\n'
         '[optional-dependencies.all]\n"mypkg[data,monitoring]" = "*"\n'
     );

def _make_extras_cli_project(tmpdir: str) -> str {
    project_path = os.path.join(tmpdir, "mypkg");
    os.makedirs(project_path, exist_ok=True);
    with open(os.path.join(project_path, "jac.toml"), "w") as f {
        f.write(_EXTRAS_JAC_TOML);
    }
    return project_path;
}

test "jac install --extras unknown group exits non-zero with helpful message" {
    with tempfile.TemporaryDirectory() as tmp {
        project_path = _make_extras_cli_project(tmp);
        result = subprocess.run(
            ["jac", "install", "--extras", "doesnotexist"],
            cwd=project_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        );
        combined = result.stdout + result.stderr;
        assert result.returncode != 0 , "Expected non-zero exit for unknown extras group";
        assert "doesnotexist" in combined , f"Error should name the bad group; got: {combined}";
        assert "Available:" in combined , f"Error should list available groups; got: {combined}";
    }
}

test "jac install --extras valid group prints Extras line" {
    with tempfile.TemporaryDirectory() as tmp {
        project_path = _make_extras_cli_project(tmp);
        result = subprocess.run(
            ["jac", "install", "--extras", "data", "monitoring"],
            cwd=project_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        );
        combined = result.stdout + result.stderr;
        assert "Extras: data, monitoring" in combined , (
            f"Expected 'Extras: data, monitoring' in output; got:\n{combined}"
        );
    }
}

test "jac install --extras all expands groups in output" {
    with tempfile.TemporaryDirectory() as tmp {
        project_path = _make_extras_cli_project(tmp);
        result = subprocess.run(
            ["jac", "install", "--extras", "all"],
            cwd=project_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        );
        combined = result.stdout + result.stderr;
        assert "Extras: all" in combined , (
            f"Expected 'Extras: all' in output; got:\n{combined}"
        );
    }
}
