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
import jaclang;
import from jaclang.cli.commands { analysis, execution, project, tools, transform }
import from jaclang.cli.commands { config as config_cmd }
import from jaclang.project.config { set_config }
import from jaclang.runtimelib.builtin { printgraph }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     EXAMPLES = os.path.join(JAC_ROOT, "examples"),
     _template_state = {"initialized": False};

def fixture_path(filename: str) -> str {
    return os.path.join(FIXTURES, filename);
}

def examples_path(path: str) -> str {
    return os.path.join(EXAMPLES, path);
}

def _assert_error_pretty_found(needle: str, haystack: str) -> None {
    for line in [
        line.strip()
        for line in needle.splitlines()
        if line.strip()
    ] {
        assert line in haystack , f"Expected line not found in:\n{haystack}";
    }
}

def _run_jac_check(test_dir: str, ignore_pattern: list = []) -> int {
    """Run jac check and return file count."""
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;

    try {
        analysis.check([test_dir], ignore=ignore_pattern);
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
def _create_clean_project(tmpdir: str) -> str {
    """Create a minimal jac project structure for testing."""
    project_path = os.path.join(tmpdir, "testproj");
    os.makedirs(project_path, exist_ok=True);

    toml_content = "[project]\nname = \"testproj\"\nversion = \"0.1.0\"\n";
    with open(os.path.join(project_path, "jac.toml"), "w") as f {
        f.write(toml_content);
    }

    os.makedirs(os.path.join(project_path, ".jac"), exist_ok=True);
    return project_path;
}

def _capture_output -> tuple {
    """Set up output capture and return (stdout_capture, stderr_capture, old_stdout, old_stderr)."""
    captured_stdout = io.StringIO();
    captured_stderr = io.StringIO();
    old_stdout = sys.stdout;
    old_stderr = sys.stderr;
    sys.stdout = captured_stdout;
    sys.stderr = captured_stderr;
    return (captured_stdout, captured_stderr, old_stdout, old_stderr);
}

def _restore_output(old_stdout: object, old_stderr: object) -> None {
    """Restore original stdout/stderr."""
    sys.stdout = old_stdout;
    sys.stderr = old_stderr;
}

def _reset_config -> None {
    """Reset the global config cache to force rediscovery."""
    import from jaclang.project { config as config_module }
    config_module._config = None;
}

def _ensure_template_registry -> None {
    """Ensure template registry is initialized once."""
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
        execution.enter(fixture_path("err2.jac"), entrypoint="speak", args=[]);
    } except Exception as e {
        print(f"Error: {e}");
    }
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    assert "Error" in stdout_value;
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
    if "jaclang.tests.fixtures.err" in sys.modules {
        del sys.modules["jaclang.tests.fixtures.err"];
    }
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        execution.enter(fixture_path("err.jac"), entrypoint="speak", args=[]);
    } except Exception {
        traceback.print_exc();
    }
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    path_to_file = fixture_path("err.impl.jac");
    assert f'"{path_to_file}", line 2' in stdout_value;
}

test "param name diff" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        execution.run(fixture_path("decl_defn_param_name.jac"));
    } except Exception {
        _ = None;
    }
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;

    expected_stdout_values = ("short_name = 42", "p1 = 64 , p2 = foobar");
    output = captured_output.getvalue();
    for exp in expected_stdout_values {
        assert exp in output;
    }
}

test "jac test err" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    analysis.test(fixture_path("baddy.jac"));
    sys.stdout = sys.__stdout__;
    sys.stderr = sys.__stderr__;
    stdout_value = captured_output.getvalue();
    path_to_file = fixture_path("baddy.test.jac");
    assert f'"{path_to_file}", line 2,' in stdout_value;
}

test "jac ast tool pass template" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.tool("pass_template");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "Sub objects." in stdout_value;
    assert stdout_value.count("def exit_") > 10;
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
        "digraph G {\n" + '  0 [label="BB0\\n\\nprint ( \\"im still here\\" ) ;", shape=box];\n' + '  1 [label="BB1\\n\\"Hello World!\\" |> print ;", shape=box];\n' + "}\n\n"
    );
    assert correct_graph == stdout_value;
}

test "del clean" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.check(f"{fixture_path('del_clean.jac')}");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "passed" in stdout_value;
}

test "run test" {
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.test(fixture_path("run_test.jac"), maxfail=2);
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert "Ran 3 tests" in stderr;
    assert "FAILED (failures=2)" in stderr;
    assert "F.F" in stderr;
}

test "run test with directory filter" {
    examples_dir = examples_path("");
    process = subprocess.Popen(
        ["jac", "test", "-d", examples_dir, "-f", "circle*", "-x"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    );
    (stdout, stderr) = process.communicate();
    assert "circle" in stdout;
    assert "circle_purfe.test" not in stdout;
    assert "circle_pure.impl" not in stdout;
}

test "run test with filter maxfail" {
    process = subprocess.Popen(
        ["jac", "test", "-f", "*run_test.jac", "-m", "3"],
        cwd=fixture_path(""),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    );
    (stdout, stderr) = process.communicate();
    assert "...F" in stderr;
    assert "F.F" in stderr;
}

test "run specific test only" {
    captured_stderr = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = captured_stderr;

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        analysis.test(fixture_path("jactest_main.jac"), test_name="from_2_to_10");
        stdout = captured.getvalue();
        stderr = captured_stderr.getvalue();
    } finally {
        sys.stdout = old_stdout;
        sys.stderr = old_stderr;
    }

    assert "Ran 1 test" in stderr;
    assert "Testing fibonacci numbers from 2 to 10." in stdout;
    assert "Testing first 2 fibonacci numbers." not in stdout;
    assert "This test should not run after import." not in stdout;
}

test "graph coverage" {
    graph_params = set(inspect.signature(tools.dot).parameters.keys());
    printgraph_params = set(inspect.signature(printgraph).parameters.keys());
    printgraph_params = printgraph_params - {"nd","file","edge_type"};
    printgraph_params.update({"initial","saveto","connection","session"});
    assert printgraph_params.issubset(graph_params);
    assert len(printgraph_params) + 2 == len(graph_params);
}

test "graph" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        tools.dot(f"{examples_path('micro/simple_walk.jac')}");
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
    import from jaclang.jac0core.program { JacProgram }

    filename = fixture_path("params/test_complex_params.jac");
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        transform.jac2py(f"{fixture_path('params/test_complex_params.jac')}");
        py_code = JacProgram().compile(file_path=filename).gen.py;

        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as temp_file {
            temp_file.write(py_code);
            py_file_path = temp_file.name;
        }

        try {
            jac_code = (
                JacProgram().compile(use_str=py_code, file_path=py_file_path).unparse()
            );
            with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as temp_file {
                temp_file.write(jac_code);
                jac_file_path = temp_file.name;
            }
            execution.run(jac_file_path);
        } finally {
            os.remove(py_file_path);
            os.remove(jac_file_path);
        }
    } finally {
        sys.stdout = old_stdout;
    }

    stdout_value = captured.getvalue().split("\n");
    assert stdout_value[-7] == "ULTIMATE_MIN: 1|def|2.5|0|test|100|0";
    assert stdout_value[-6] == "ULTIMATE_FULL: 1|custom|3.14|3|req|200|1";
    assert stdout_value[-5] == "SEPARATORS: 42";
    assert stdout_value[-4] == "EDGE_MIX: 1-test-2-True-1";
    assert stdout_value[-3] == "RECURSIVE: 7 11";
    assert stdout_value[-2] == "VALIDATION: x:1,y:2.5,z:10,args:1,w:True,kwargs:1";
}

test "caching issue" {
    test_file = fixture_path("test_caching_issue.jac");
    test_cases = [(10, True), (11, False)];
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
        if is_passed {
            assert "Passed successfully." in stdout;
            assert "." in stderr;
        } else {
            assert "Passed successfully." not in stdout;
            assert "F" in stderr;
        }
    }
    os.remove(test_file);
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
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as temp_file {
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

test "positional args with defaults" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = config_cmd.plugins();
    } finally {
        sys.stdout = old_stdout;
    }
    stdout = captured.getvalue();
    assert result == 0 , "jac plugins should work without action argument";
    assert "installed jac plugin" in stdout.lower() , (
        "Output should show installed plugins list"
    );

    # Verify explicit list action produces the same result
    captured_explicit = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_explicit;
    try {
        config_cmd.plugins(action="list");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_explicit = captured_explicit.getvalue();
    assert stdout == stdout_explicit , (
        "jac plugins and jac plugins list should produce identical output"
    );
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
        def get_root_files(path: Path) -> set {
            """Get files/dirs in project root, excluding .jac directory."""
            items = set();
            for item in path.iterdir() {
                if item.name != ".jac" {
                    items.add(item.name);
                }
            }
            return items;
        }

        files_before_run = get_root_files(project_path);

        # Run jac run main.jac (change to project directory first)
        os.chdir(project_path);
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            result = execution.run("main.jac");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();

        assert result == 0 , "jac run failed";
        assert f"Hello from {project_name}!" in stdout;

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

test "jac create default name jactastic" {
    _ensure_template_registry();
    _tmpdir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(_tmpdir);
    try {
        cli_dir = Path(_tmpdir);
        # First create should use jactastic
        assert project.create() == 0;
        assert (cli_dir / "jactastic").is_dir();

        # Second create should use jactastic1
        assert project.create() == 0;
        assert (cli_dir / "jactastic1").is_dir();

        # Third create should use jactastic2
        assert project.create() == 0;
        assert (cli_dir / "jactastic2").is_dir();
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(_tmpdir, ignore_errors=True);
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
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        try {
            config_cmd.config(action="path");
        } finally {
            sys.stdout = old_stdout;
        }
        stdout = captured.getvalue();
        assert "jac.toml" in stdout;
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
        "attempted relative import" in stderr
        or "ImportError" in stderr
        or "__package__" in stderr
    ) , "stderr should contain import error message";

    # Should show the source code line that caused the error
    assert "import from .nonexistent_module" in stderr , (
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
    import from jaclang.jac0core.program { JacProgram }

    program = JacProgram();
    program.compile(fixture_path("test_syntax_err.jac"));
    assert len(program.errors_had) == 1 , (
        f"Expected 1 error with improved error reporting, got {len(program.errors_had)}"
    );
    _assert_error_pretty_found(
        """
        2 |
        3 | walker w {
        4 |     can foo {
          |             ^
        5 |         print "Missing semicolon"
        6 |     }
    """,
        program.errors_had[0].pretty_print()
    );
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

test "jac grammar lark" {
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        result = analysis.grammar(lark=True);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert result == 0 , "grammar lark command should exit with code 0";
    assert len(stdout_value) > 0 , "Lark output should not be empty";
}

test "jac cli check ignore patterns" {
    test_dir = fixture_path("deep");
    result_count = _run_jac_check(
        test_dir, ["deeper", "one_lev_dup.jac", "one_lev.jac", "mycode"]
    );
    assert result_count == 1;
}

test "jac cli check ignore with wildcards" {
    """Test --ignore with multiple wildcard patterns."""
    test_dir = fixture_path("deep");
    result_count = _run_jac_check(test_dir, ["one_lev*", "snd_*"]);
    assert result_count == 3;
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
