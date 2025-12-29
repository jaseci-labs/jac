"""Test Jac cli module."""

import contextlib
import inspect
import io
import os
import re
import subprocess
import sys
import tempfile
import traceback
from collections.abc import Callable
from contextlib import AbstractContextManager

import pytest

from jaclang.cli import cli
from jaclang.cli.cmdreg import cmd_registry, extract_param_descriptions
from jaclang.runtimelib.builtin import printgraph


def test_jac_cli_run(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        cli.run(fixture_path("hello.jac"))

    stdout_value = output.getvalue()
    assert "Hello World!" in stdout_value


def test_jac_cli_run_python_file(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        cli.run(fixture_path("python_run_test.py"))

    stdout_value = output.getvalue()
    assert "Hello from Python!" in stdout_value
    assert "This is a test Python file." in stdout_value
    assert "Result: 42" in stdout_value
    assert "Python execution completed." in stdout_value
    assert "10" in stdout_value


def test_jac_run_py_fstr(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        cli.run(fixture_path("pyfunc_fstr.py"))

    stdout_value = output.getvalue()
    assert "Hello Peter" in stdout_value
    assert "Hello Peter Peter" in stdout_value
    assert "Peter squared is Peter Peter" in stdout_value
    assert "PETER!  wrong poem" in stdout_value
    assert "Hello Peter , yoo mother is Mary. Myself, I am Peter." in stdout_value
    assert "Left aligned: Apple | Price: 1.23" in stdout_value
    assert "name = Peter 🤔" in stdout_value


def test_jac_run_py_fmt(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        cli.run(fixture_path("pyfunc_fmt.py"))

    stdout_value = output.getvalue()
    assert "One" in stdout_value
    assert "Two" in stdout_value
    assert "Three" in stdout_value
    assert "baz" in stdout_value
    assert "Processing..." in stdout_value
    assert "Four" in stdout_value
    assert "The End." in stdout_value


def test_jac_run_pyfunc_kwesc(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        cli.run(fixture_path("pyfunc_kwesc.py"))

    stdout_value = output.getvalue()
    out = stdout_value.split("\n")
    assert "89" in out[0]
    assert "(13, (), {'a': 1, 'b': 2})" in out[1]
    assert "Functions: [{'name': 'replace_lines'" in out[2]
    assert "Dict: 90" in out[3]


def test_jac_cli_alert_based_err(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output

    try:
        cli.enter(fixture_path("err2.jac"), entrypoint="speak", args=[])
    except Exception as e:
        print(f"Error: {e}")

    sys.stdout = sys.__stdout__
    sys.stderr = sys.__stderr__
    stdout_value = captured_output.getvalue()
    assert "Error" in stdout_value


def test_jac_cli_alert_based_runtime_err(fixture_path: Callable[[str], str]) -> None:
    """Test runtime errors with internal calls collapsed (default behavior)."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output

    with pytest.raises(SystemExit) as excinfo:
        cli.run(fixture_path("err_runtime.jac"))

    sys.stdout = sys.__stdout__
    sys.stderr = sys.__stderr__

    assert excinfo.value.code == 1

    output = captured_output.getvalue()

    expected_stderr_values = (
        "Error: list index out of range",
        "    print(some_list[invalid_index]);",
        "          ^^^^^^^^^^^^^^^^^^^^^^^^",
        "  at bar() ",
        "  at foo() ",
        "  at <module> ",
        "... [internal runtime calls]",
    )
    for exp in expected_stderr_values:
        assert exp in output

    internal_call_patterns = (
        "meta_importer.py",
        "runtime.py",
        "/jaclang/vendor/",
        "pluggy",
        "_multicall",
        "_hookexec",
    )
    for pattern in internal_call_patterns:
        assert pattern not in output


def test_jac_impl_err(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    if "jaclang.tests.fixtures.err" in sys.modules:
        del sys.modules["jaclang.tests.fixtures.err"]
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output

    try:
        cli.enter(fixture_path("err.jac"), entrypoint="speak", args=[])
    except Exception:
        traceback.print_exc()

    sys.stdout = sys.__stdout__
    sys.stderr = sys.__stderr__
    stdout_value = captured_output.getvalue()
    path_to_file = fixture_path("err.impl.jac")
    assert f'"{path_to_file}", line 2' in stdout_value


def test_param_name_diff(fixture_path: Callable[[str], str]) -> None:
    """Test when parameter name from definitinon and declaration are mismatched."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    with contextlib.suppress(Exception):
        cli.run(fixture_path("decl_defn_param_name.jac"))
    sys.stdout = sys.__stdout__
    sys.stderr = sys.__stderr__

    expected_stdout_values = (
        "short_name = 42",
        "p1 = 64 , p2 = foobar",
    )
    output = captured_output.getvalue()
    for exp in expected_stdout_values:
        assert exp in output


def test_jac_test_err(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    cli.test(fixture_path("baddy.jac"))
    sys.stdout = sys.__stdout__
    sys.stderr = sys.__stderr__
    stdout_value = captured_output.getvalue()
    path_to_file = fixture_path("baddy.test.jac")
    assert f'"{path_to_file}", line 2,' in stdout_value


def test_jac_ast_tool_pass_template(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        cli.tool("pass_template")

    stdout_value = output.getvalue()
    assert "Sub objects." in stdout_value
    assert stdout_value.count("def exit_") > 10


def test_ast_print(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    with capture_stdout() as output:
        cli.tool("ir", ["ast", f"{fixture_path('hello.jac')}"])

    stdout_value = output.getvalue()
    assert "+-- Token" in stdout_value


def test_ast_printgraph(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    with capture_stdout() as output:
        cli.tool("ir", ["ast.", f"{fixture_path('hello.jac')}"])

    stdout_value = output.getvalue()
    assert '[label="MultiString"]' in stdout_value


def test_cfg_printgraph(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print CFG."""
    with capture_stdout() as output:
        cli.tool("ir", ["cfg.", f"{fixture_path('hello.jac')}"])

    stdout_value = output.getvalue()
    correct_graph = (
        "digraph G {\n"
        '  0 [label="BB0\\n\\nprint ( \\"im still here\\" ) ;", shape=box];\n'
        '  1 [label="BB1\\n\\"Hello World!\\" |> print ;", shape=box];\n'
        "}\n\n"
    )
    assert correct_graph == stdout_value


def test_del_clean(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    with capture_stdout() as output:
        cli.check(f"{fixture_path('del_clean.jac')}")

    stdout_value = output.getvalue()
    assert "0 errors, 0 warnings" in stdout_value


def test_build_and_run(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    if os.path.exists(f"{fixture_path('needs_import.jir')}"):
        os.remove(f"{fixture_path('needs_import.jir')}")
    with capture_stdout() as output:
        cli.build(f"{fixture_path('needs_import.jac')}")
        cli.run(f"{fixture_path('needs_import.jir')}")

    stdout_value = output.getvalue()
    assert "Errors: 0, Warnings: 0" in stdout_value
    assert "<module 'pyfunc' from" in stdout_value


def test_run_test(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    process = subprocess.Popen(
        ["jac", "test", f"{fixture_path('run_test.jac')}", "-m 2"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "Ran 3 tests" in stderr
    assert "FAILED (failures=2)" in stderr
    assert "F.F" in stderr

    process = subprocess.Popen(
        [
            "jac",
            "test",
            "-d" + f"{fixture_path('../../../')}",
            "-f" + "circle*",
            "-x",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "circle" in stdout
    assert "circle_purfe.test" not in stdout
    assert "circle_pure.impl" not in stdout

    process = subprocess.Popen(
        ["jac", "test", "-f" + "*run_test.jac", "-m 3"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "...F" in stderr
    assert "F.F" in stderr


def test_run_specific_test_only(fixture_path: Callable[[str], str]) -> None:
    """Test a specific test case."""
    process = subprocess.Popen(
        [
            "jac",
            "test",
            "-t",
            "from_2_to_10",
            fixture_path("jactest_main.jac"),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "Ran 1 test" in stderr
    assert "Testing fibonacci numbers from 2 to 10." in stdout
    assert "Testing first 2 fibonacci numbers." not in stdout
    assert "This test should not run after import." not in stdout


def test_graph_coverage() -> None:
    """Test for coverage of graph cmd."""
    graph_params = set(inspect.signature(cli.dot).parameters.keys())
    printgraph_params = set(inspect.signature(printgraph).parameters.keys())
    printgraph_params = printgraph_params - {
        "node",
        "file",
        "edge_type",
    }
    printgraph_params.update({"initial", "saveto", "connection", "session"})
    assert printgraph_params.issubset(graph_params)
    assert len(printgraph_params) + 2 == len(graph_params)


def test_graph(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for graph CLI cmd."""
    with capture_stdout() as output:
        cli.dot(f"{examples_path('reference/connect_expressions_(osp).jac')}")

    stdout_value = output.getvalue()
    if os.path.exists("connect_expressions_(osp).dot"):
        os.remove("connect_expressions_(osp).dot")
    assert ">>> Graph content saved to" in stdout_value
    assert "connect_expressions_(osp).dot\n" in stdout_value


def test_py_to_jac(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for graph CLI cmd."""
    with capture_stdout() as output:
        cli.py2jac(f"{fixture_path('pyfunc.py')}")

    stdout_value = output.getvalue()
    assert "def my_print(x: object) -> None" in stdout_value
    assert "class MyClass {" in stdout_value
    assert '"""Print function."""' in stdout_value


def test_lambda_arg_annotation(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for lambda argument annotation."""
    with capture_stdout() as output:
        cli.jac2py(f"{fixture_path('lambda_arg_annotation.jac')}")

    stdout_value = output.getvalue()
    assert "x = lambda a, b: b + a" in stdout_value
    assert "y = lambda: 567" in stdout_value
    assert "f = lambda x: 'even' if x % 2 == 0 else 'odd'" in stdout_value


def test_lambda_self(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for lambda argument annotation."""
    with capture_stdout() as output:
        cli.jac2py(f"{fixture_path('lambda_self.jac')}")

    stdout_value = output.getvalue()
    assert "def travel(self, here: City) -> None:" in stdout_value
    assert "def foo(a: int) -> None:" in stdout_value
    assert "x = lambda a, b: b + a" in stdout_value
    assert "def visit_city(self, c: City) -> None:" in stdout_value
    assert "sorted(users, key=lambda x: x['email'], reverse=True)" in stdout_value


def test_param_arg(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for lambda argument annotation."""
    from jaclang.pycore.program import JacProgram

    filename = fixture_path("params/test_complex_params.jac")
    with capture_stdout() as output:
        cli.jac2py(f"{fixture_path('params/test_complex_params.jac')}")
        py_code = JacProgram().compile(file_path=filename).gen.py

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".py", delete=False
        ) as temp_file:
            temp_file.write(py_code)
            py_file_path = temp_file.name

        try:
            jac_code = (
                JacProgram().compile(use_str=py_code, file_path=py_file_path).unparse()
            )
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as temp_file:
                temp_file.write(jac_code)
                jac_file_path = temp_file.name
            cli.run(jac_file_path)
        finally:
            os.remove(py_file_path)
            os.remove(jac_file_path)

    stdout_value = output.getvalue().split("\n")
    assert stdout_value[-7] == "ULTIMATE_MIN: 1|def|2.5|0|test|100|0"
    assert stdout_value[-6] == "ULTIMATE_FULL: 1|custom|3.14|3|req|200|1"
    assert stdout_value[-5] == "SEPARATORS: 42"
    assert stdout_value[-4] == "EDGE_MIX: 1-test-2-True-1"
    assert stdout_value[-3] == "RECURSIVE: 7 11"
    assert stdout_value[-2] == "VALIDATION: x:1,y:2.5,z:10,args:1,w:True,kwargs:1"


def test_caching_issue(fixture_path: Callable[[str], str]) -> None:
    """Test for Caching Issue."""
    test_file = fixture_path("test_caching_issue.jac")
    test_cases = [(10, True), (11, False)]
    for x, is_passed in test_cases:
        with open(test_file, "w") as f:
            f.write(
                f"""
            test mytest{{
                assert 10 == {x};
            }}
            """
            )
        process = subprocess.Popen(
            ["jac", "test", test_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        if is_passed:
            assert "Passed successfully." in stdout
            assert "." in stderr
        else:
            assert "Passed successfully." not in stdout
            assert "F" in stderr
    os.remove(test_file)


def test_cli_docstring_parameters() -> None:
    """Test that all CLI command parameters are documented in their docstrings."""
    commands = {}
    for name, _ in cmd_registry.registry.items():
        if hasattr(cli, name):
            commands[name] = getattr(cli, name)

    missing_params = {}

    for cmd_name, cmd_func in commands.items():
        signature_params = set(inspect.signature(cmd_func).parameters.keys())
        docstring = cmd_func.__doc__ or ""

        args_match = re.search(r"Args:(.*?)(?:\n\n|\Z)", docstring, re.DOTALL)
        if not args_match:
            missing_params[cmd_name] = list(signature_params)
            continue

        args_section = args_match.group(1)
        doc_params = set()
        for line in args_section.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            param_match = re.match(r"\s*([a-zA-Z0-9_]+)(?:\s*\([^)]*\))?:\s*", line)
            if param_match:
                doc_params.add(param_match.group(1))

        undocumented_params = signature_params - doc_params
        if undocumented_params:
            missing_params[cmd_name] = list(undocumented_params)

    assert missing_params == {}, (
        f"The following CLI commands have undocumented parameters: {missing_params}"
    )


def test_cli_help_uses_docstring_descriptions() -> None:
    """Test that CLI help text uses parameter descriptions from docstrings."""
    test_commands = ["run", "dot", "test"]

    for cmd_name in test_commands:
        if not hasattr(cli, cmd_name):
            continue

        cmd_func = getattr(cli, cmd_name)
        docstring = cmd_func.__doc__ or ""
        docstring_param_descriptions = extract_param_descriptions(docstring)

        if not docstring_param_descriptions:
            continue

        process = subprocess.Popen(
            ["jac", cmd_name, "--help"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        help_text, _ = process.communicate()

        for param_name, description in docstring_param_descriptions.items():
            description_start = description.split()[:3]
            description_pattern = r"\s+".join(
                re.escape(word) for word in description_start
            )
            assert re.search(description_pattern, help_text), (
                f"Parameter description for '{param_name}' not found in help text for '{cmd_name}'"
            )


def test_run_jac_name_py(fixture_path: Callable[[str], str]) -> None:
    """Test a specific test case."""
    process = subprocess.Popen(
        [
            "jac",
            "run",
            fixture_path("py_run.py"),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "Hello, World!" in stdout
    assert "Sum: 8" in stdout


def test_jac_run_py_bugs(fixture_path: Callable[[str], str]) -> None:
    """Test jac run python files."""
    process = subprocess.Popen(
        [
            "jac",
            "run",
            fixture_path("jac_run_py_bugs.py"),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "Hello, my name is Alice and I am 30 years old." in stdout
    assert "MyModule initialized!" in stdout


def test_cli_defaults_to_run_with_file(fixture_path: Callable[[str], str]) -> None:
    """jac myfile.jac should behave like jac run myfile.jac."""
    process = subprocess.Popen(
        [
            "jac",
            fixture_path("hello.jac"),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "Hello World!" in stdout


def test_cli_error_exit_codes(fixture_path: Callable[[str], str]) -> None:
    """Test that CLI commands return non-zero exit codes on errors."""
    # Test run command with syntax error
    process = subprocess.Popen(
        ["jac", "run", fixture_path("err2.jac")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 1, (
        "run command should exit with code 1 on syntax error"
    )
    assert "Error" in stderr

    # Test build command with syntax error
    process = subprocess.Popen(
        ["jac", "build", fixture_path("err2.jac")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 1, (
        "build command should exit with code 1 on compilation error"
    )

    # Test check command with syntax error
    process = subprocess.Popen(
        ["jac", "check", fixture_path("err2.jac")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 1, (
        "check command should exit with code 1 on type check error"
    )

    # Test format command with file that needs changes (exits 1 for pre-commit usage)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False
    ) as temp_file:
        temp_file.write('with entry{print("hello");}')  # Needs formatting
        temp_path = temp_file.name
    try:
        process = subprocess.Popen(
            ["jac", "format", temp_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        assert process.returncode == 1, (
            "format command should exit with code 1 when file is changed"
        )
    finally:
        os.remove(temp_path)

    # Test check command with invalid file type
    process = subprocess.Popen(
        ["jac", "check", "/nonexistent.txt"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 1, (
        "check command should exit with code 1 on invalid file type"
    )
    assert "is not a .jac file" in stderr

    # Test tool command with non-existent tool
    process = subprocess.Popen(
        ["jac", "tool", "nonexistent_tool"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 1, (
        "tool command should exit with code 1 on non-existent tool"
    )
    assert "not found" in stderr

    # Test successful run returns exit code 0
    process = subprocess.Popen(
        ["jac", "run", fixture_path("hello.jac")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert process.returncode == 0, "run command should exit with code 0 on success"
    assert "Hello World!" in stdout


def test_format_tracks_changed_files() -> None:
    """Test that format command correctly tracks and reports changed files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a file that needs formatting (bad indentation/spacing)
        needs_formatting = os.path.join(tmpdir, "needs_format.jac")
        with open(needs_formatting, "w") as f:
            f.write('with entry{print("hello");}')

        # Create a file that is already formatted
        already_formatted = os.path.join(tmpdir, "already_formatted.jac")
        with open(already_formatted, "w") as f:
            f.write('with entry {\n    print("hello");\n}\n')

        # Run format on the directory
        process = subprocess.Popen(
            ["jac", "format", tmpdir],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()

        # Exit code 1 indicates files were changed (useful for pre-commit hooks)
        assert process.returncode == 1
        assert "2/2" in stderr
        assert "(1 changed)" in stderr
