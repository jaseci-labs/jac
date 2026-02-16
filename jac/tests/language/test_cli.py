"""Test Jac cli module."""

import contextlib
import inspect
import io
import os
import re
import sys
import tempfile
import traceback
import typing
from collections.abc import Callable
from contextlib import AbstractContextManager
from pathlib import Path

import pytest

from jaclang.cli.commands import (  # type: ignore[attr-defined]
    analysis,
    execution,
    project,
    tools,
    transform,
)
from jaclang.cli.commands import (  # type: ignore[attr-defined]
    config as config_cmd,
)
from jaclang.project.config import set_config
from jaclang.runtimelib.builtin import printgraph


def test_jac_cli_run(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        execution.run(fixture_path("hello.jac"))

    stdout_value = output.getvalue()
    assert "Hello World!" in stdout_value


def test_jac_cli_run_python_file(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        execution.run(fixture_path("python_run_test.py"))

    stdout_value = output.getvalue()
    assert "Hello from Python!" in stdout_value
    assert "This is a test Python file." in stdout_value
    assert "Result: 42" in stdout_value
    assert "Python execution completed." in stdout_value
    assert "10" in stdout_value


def _assert_error_pretty_found(needle: str, haystack: str) -> None:
    for line in [line.strip() for line in needle.splitlines() if line.strip()]:
        assert line in haystack, f"Expected line '{line}' not found in:\n{haystack}"


def test_jac_run_py_fstr(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test running Python files with jac run command."""
    with capture_stdout() as output:
        execution.run(fixture_path("pyfunc_fstr.py"))

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
        execution.run(fixture_path("pyfunc_fmt.py"))

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
        execution.run(fixture_path("pyfunc_kwesc.py"))

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
        execution.enter(fixture_path("err2.jac"), entrypoint="speak", args=[])
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

    try:
        result = execution.run(fixture_path("err_runtime.jac"))
    finally:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__

    assert result == 1

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
        execution.enter(fixture_path("err.jac"), entrypoint="speak", args=[])
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
        execution.run(fixture_path("decl_defn_param_name.jac"))
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
    analysis.test(fixture_path("baddy.jac"))
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
        tools.tool("pass_template")

    stdout_value = output.getvalue()
    assert "Sub objects." in stdout_value
    assert stdout_value.count("def exit_") > 10


def test_ast_print(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    with capture_stdout() as output:
        tools.tool("ir", ["ast", f"{fixture_path('hello.jac')}"])

    stdout_value = output.getvalue()
    assert "+-- Token" in stdout_value


def test_ast_printgraph(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print AstTool."""
    with capture_stdout() as output:
        tools.tool("ir", ["ast.", f"{fixture_path('hello.jac')}"])

    stdout_value = output.getvalue()
    assert 'label="MultiString"' in stdout_value


def test_cfg_printgraph(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Testing for print CFG."""
    with capture_stdout() as output:
        tools.tool("ir", ["cfg.", f"{fixture_path('hello.jac')}"])

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
        analysis.check(f"{fixture_path('del_clean.jac')}")

    stdout_value = output.getvalue()
    assert "0 errors, 0 warnings" in stdout_value


def test_run_test(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for jac test command with filepath."""
    captured_stderr = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = captured_stderr

    try:
        with capture_stdout():
            analysis.test(fixture_path("run_test.jac"), maxfail=2)
        stderr = captured_stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    assert "Ran 3 tests" in stderr
    assert "FAILED (failures=2)" in stderr
    assert "F.F" in stderr


def test_run_test_with_directory_filter(examples_path: Callable[[str], str]) -> None:
    """Test jac test with directory and filter options.

    Note: This test uses subprocess because the test runner has internal state
    that can interfere between multiple invocations in the same process.
    """
    import subprocess

    examples_dir = examples_path("")
    process = subprocess.Popen(
        ["jac", "test", "-d", examples_dir, "-f", "circle*", "-x"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "circle" in stdout
    assert "circle_purfe.test" not in stdout
    assert "circle_pure.impl" not in stdout


def test_run_test_with_filter_maxfail(fixture_path: Callable[[str], str]) -> None:
    """Test jac test with filter and maxfail options.

    Note: This test uses subprocess because the test runner has internal state
    that can interfere between multiple invocations in the same process.
    """
    import subprocess

    process = subprocess.Popen(
        ["jac", "test", "-f", "*run_test.jac", "-m", "3"],
        cwd=fixture_path(""),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout, stderr = process.communicate()
    assert "...F" in stderr
    assert "F.F" in stderr


def test_run_specific_test_only(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test a specific test case."""
    captured_stderr = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = captured_stderr

    try:
        with capture_stdout() as output:
            analysis.test(fixture_path("jactest_main.jac"), test_name="from_2_to_10")
        stdout = output.getvalue()
        stderr = captured_stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    assert "Ran 1 test" in stderr
    assert "Testing fibonacci numbers from 2 to 10." in stdout
    assert "Testing first 2 fibonacci numbers." not in stdout
    assert "This test should not run after import." not in stdout


def test_graph_coverage() -> None:
    """Test for coverage of graph cmd."""
    graph_params = set(inspect.signature(tools.dot).parameters.keys())
    printgraph_params = set(inspect.signature(printgraph).parameters.keys())
    printgraph_params = printgraph_params - {
        "nd",
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
        tools.dot(f"{examples_path('micro/simple_walk.jac')}")

    stdout_value = output.getvalue()
    if os.path.exists("simple_walk.dot"):
        os.remove("simple_walk.dot")
    assert ">>> Graph content saved to" in stdout_value
    assert "simple_walk.dot\n" in stdout_value


def test_py_to_jac(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test for graph CLI cmd."""
    with capture_stdout() as output:
        transform.py2jac(f"{fixture_path('pyfunc.py')}")

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
        transform.jac2py(f"{fixture_path('lambda_arg_annotation.jac')}")

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
        transform.jac2py(f"{fixture_path('lambda_self.jac')}")

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
    from jaclang.jac0core.program import JacProgram

    filename = fixture_path("params/test_complex_params.jac")
    with capture_stdout() as output:
        transform.jac2py(f"{fixture_path('params/test_complex_params.jac')}")
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
            execution.run(jac_file_path)
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
    """Test for Caching Issue.

    Note: This test uses subprocess because it tests the caching behavior
    across multiple compilations, which requires process isolation to avoid
    in-memory state interference.
    """
    import subprocess

    test_file = fixture_path("test_caching_issue.jac")
    test_cases = [(10, True), (11, False)]
    for x, is_passed in test_cases:
        with open(test_file, "w") as f:
            f.write(
                f"""
            test "mytest" {{
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


def test_run_jac_name_py(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test a specific test case."""
    with capture_stdout() as output:
        execution.run(fixture_path("py_run.py"))
    stdout = output.getvalue()
    assert "Hello, World!" in stdout
    assert "Sum: 8" in stdout


def test_jac_run_py_bugs(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test jac run python files."""
    with capture_stdout() as output:
        execution.run(fixture_path("jac_run_py_bugs.py"))
    stdout = output.getvalue()
    assert "Hello, my name is Alice and I am 30 years old." in stdout
    assert "MyModule initialized!" in stdout


def test_cli_defaults_to_run_with_file(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """jac myfile.jac should behave like jac run myfile.jac."""
    # The default behavior (jac <file>) routes to execution.run
    with capture_stdout() as output:
        execution.run(fixture_path("hello.jac"))
    stdout = output.getvalue()
    assert "Hello World!" in stdout


def test_cli_error_exit_codes(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that CLI commands return non-zero exit codes on errors."""
    # Test run command with syntax error
    captured_stderr = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = captured_stderr

    try:
        with capture_stdout() as output:
            result = execution.run(fixture_path("err2.jac"))
        stderr = captured_stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    assert result == 1, "run command should exit with code 1 on syntax error"
    assert "Error" in stderr

    # Test check command with syntax error
    captured_stderr = io.StringIO()
    sys.stderr = captured_stderr

    try:
        with capture_stdout() as output:
            result = analysis.check([fixture_path("err2.jac")])
    finally:
        sys.stderr = old_stderr

    assert result == 1, "check command should exit with code 1 on type check error"

    # Test format command with file that needs changes (exits 1 for pre-commit usage)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False
    ) as temp_file:
        temp_file.write('with entry{print("hello");}')  # Needs formatting
        temp_path = temp_file.name
    try:
        with capture_stdout() as output:
            result = analysis.format([temp_path])
        assert result == 1, (
            "format command should exit with code 1 when file is changed"
        )
    finally:
        os.remove(temp_path)

    # Test check command with invalid file type
    captured_stderr = io.StringIO()
    sys.stderr = captured_stderr

    try:
        with capture_stdout() as output:
            result = analysis.check(["/nonexistent.txt"])
        stderr = captured_stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    assert result == 1, "check command should exit with code 1 on invalid file type"
    assert "is not a .jac file" in stderr

    # Test tool command with non-existent tool
    captured_stderr = io.StringIO()
    sys.stderr = captured_stderr

    try:
        with capture_stdout() as output:
            result = tools.tool("nonexistent_tool")
        stderr = captured_stderr.getvalue()
    finally:
        sys.stderr = old_stderr

    assert result == 1, "tool command should exit with code 1 on non-existent tool"
    assert "not found" in stderr

    # Test successful run returns exit code 0
    with capture_stdout() as output:
        result = execution.run(fixture_path("hello.jac"))
    stdout = output.getvalue()
    assert result == 0, "run command should exit with code 0 on success"
    assert "Hello World!" in stdout


def test_positional_args_with_defaults(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that positional arguments with defaults are optional."""
    # Test that 'jac plugins' works without providing the 'action' argument
    # The action parameter has a default of 'list', so it should be optional
    with capture_stdout() as output:
        result = config_cmd.plugins()
    stdout = output.getvalue()
    assert result == 0, "'jac plugins' should work without action argument"
    # Check for plugins list output (case-insensitive, handles Rich formatting)
    assert "installed jac plugin" in stdout.lower(), (
        "Output should show installed plugins list"
    )

    # Verify explicit 'list' action produces the same result
    with capture_stdout() as output_explicit:
        config_cmd.plugins(action="list")
    stdout_explicit = output_explicit.getvalue()
    assert stdout == stdout_explicit, (
        "'jac plugins' and 'jac plugins list' should produce identical output"
    )


def test_format_tracks_changed_files(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
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
        captured_stderr = io.StringIO()
        old_stderr = sys.stderr
        sys.stderr = captured_stderr

        try:
            with capture_stdout() as output:
                result = analysis.format([tmpdir])
            stdout = output.getvalue()
            stderr = captured_stderr.getvalue()
        finally:
            sys.stderr = old_stderr

        # Exit code 1 indicates files were changed (useful for pre-commit hooks)
        assert result == 1
        # Output may go to stdout or stderr depending on console implementation
        combined_output = stdout + stderr
        assert "2/2" in combined_output
        assert "(1 changed)" in combined_output


def test_format_preserves_file_on_syntax_error(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that format does not overwrite a file that has syntax errors."""
    with tempfile.TemporaryDirectory() as tmpdir:
        broken_file = os.path.join(tmpdir, "broken.jac")
        original_content = 'can foo() -> {{\n    print("broken syntax;\n}\n'
        with open(broken_file, "w") as f:
            f.write(original_content)

        captured_stderr = io.StringIO()
        old_stderr = sys.stderr
        sys.stderr = captured_stderr
        try:
            with capture_stdout():
                analysis.format([broken_file])
        finally:
            sys.stderr = old_stderr

        with open(broken_file) as f:
            assert f.read() == original_content, (
                "jac format should not modify a file with syntax errors"
            )


def test_jac_create_and_run_no_root_files(
    cli_test_dir: Path,
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that jac create + jac run doesn't create files outside .jac/ directory."""
    project_name = "test-no-root-files"
    project_path = cli_test_dir / project_name

    # Run jac create to create the project
    with capture_stdout() as output:
        result = project.create(project_name)
    assert result == 0, "jac create failed"

    # Record files after create (before run)
    def get_root_files(path: Path) -> set[str]:
        """Get files/dirs in project root, excluding .jac directory."""
        items = set()
        for item in path.iterdir():
            if item.name != ".jac":
                items.add(item.name)
        return items

    files_before_run = get_root_files(project_path)

    # Run jac run main.jac (change to project directory first)
    original_cwd = os.getcwd()
    os.chdir(project_path)
    try:
        with capture_stdout() as output:
            result = execution.run("main.jac")
        stdout = output.getvalue()
    finally:
        os.chdir(original_cwd)

    assert result == 0, "jac run failed"
    assert f"Hello from {project_name}!" in stdout

    # Record files after run
    files_after_run = get_root_files(project_path)

    # Check no new files were created in project root
    new_files = files_after_run - files_before_run
    assert not new_files, (
        f"jac run created unexpected files in project root: {new_files}. "
        "All runtime files should be in .jac/ directory."
    )


def test_jac_create_default_name_jactastic(cli_test_dir: Path) -> None:
    """Test that jac create without a name defaults to 'jactastic' with incrementing numbers."""
    # First create should use 'jactastic'
    assert project.create() == 0
    assert (cli_test_dir / "jactastic").is_dir()

    # Second create should use 'jactastic1'
    assert project.create() == 0
    assert (cli_test_dir / "jactastic1").is_dir()

    # Third create should use 'jactastic2'
    assert project.create() == 0
    assert (cli_test_dir / "jactastic2").is_dir()


class TestConfigCommand:
    """Tests for the jac config CLI command."""

    @pytest.fixture
    def project_dir(self, tmp_path: Path):
        """Create a temporary project directory with jac.toml."""
        toml_content = """[project]
name = "test-project"
version = "1.0.0"
description = "A test project"

[run]
cache = false

[build]
typecheck = true

[test]
verbose = true
"""
        toml_path = tmp_path / "jac.toml"
        toml_path.write_text(toml_content)
        original_cwd = os.getcwd()
        os.chdir(tmp_path)
        # Reset global config to force re-discovery from new directory
        set_config(None)  # type: ignore[arg-type]
        try:
            yield str(tmp_path)
        finally:
            os.chdir(original_cwd)
            # Reset config again after test
            set_config(None)  # type: ignore[arg-type]

    @pytest.fixture
    def capture(self) -> Callable[[], AbstractContextManager[io.StringIO]]:
        """Fixture to capture stdout."""

        @contextlib.contextmanager
        def _capture() -> typing.Generator[io.StringIO, None, None]:
            captured = io.StringIO()
            old_stdout = sys.stdout
            sys.stdout = captured
            try:
                yield captured
            finally:
                sys.stdout = old_stdout

        return _capture

    def test_config_groups(self, project_dir: str, capture: Callable) -> None:
        """Test jac config groups lists available configuration groups."""
        with capture() as output:
            result = config_cmd.config(action="groups")
        stdout = output.getvalue()
        assert result == 0
        assert "project" in stdout
        assert "run" in stdout
        assert "build" in stdout
        assert "test" in stdout
        assert "serve" in stdout

    def test_config_path(self, project_dir: str, capture: Callable) -> None:
        """Test jac config path shows path to config file."""
        with capture() as output:
            result = config_cmd.config(action="path")
        stdout = output.getvalue()
        assert result == 0
        assert "jac.toml" in stdout

    def test_config_show(self, project_dir: str, capture: Callable) -> None:
        """Test jac config show displays only explicitly set values."""
        with capture() as output:
            result = config_cmd.config(action="show")
        stdout = output.getvalue()
        assert result == 0
        # Should show explicitly set values
        assert "test-project" in stdout
        assert "1.0.0" in stdout

    def test_config_show_group(self, project_dir: str, capture: Callable) -> None:
        """Test jac config show with group filter."""
        with capture() as output:
            result = config_cmd.config(action="show", group="project")
        stdout = output.getvalue()
        assert result == 0
        assert "test-project" in stdout

    def test_config_list(self, project_dir: str, capture: Callable) -> None:
        """Test jac config list displays all settings including defaults."""
        with capture() as output:
            result = config_cmd.config(action="list")
        stdout = output.getvalue()
        assert result == 0
        # Should show all settings including defaults
        assert "project" in stdout or "name" in stdout

    def test_config_get(self, project_dir: str, capture: Callable) -> None:
        """Test jac config get retrieves a specific setting."""
        with capture() as output:
            result = config_cmd.config(action="get", key="project.name")
        stdout = output.getvalue()
        assert result == 0
        assert "test-project" in stdout

    def test_config_set_and_unset(self, project_dir: str, capture: Callable) -> None:
        """Test jac config set and unset modify settings."""
        # Set a new value
        with capture() as output:
            result = config_cmd.config(
                action="set", key="project.description", value="Updated desc"
            )
        assert result == 0

        # Verify the value was set
        with capture() as output:
            result = config_cmd.config(action="get", key="project.description")
        stdout = output.getvalue()
        assert "Updated desc" in stdout

        # Unset the value
        with capture() as output:
            result = config_cmd.config(action="unset", key="project.description")
        assert result == 0

    def test_config_output_json(self, project_dir: str, capture: Callable) -> None:
        """Test jac config with JSON output format."""
        with capture() as output:
            result = config_cmd.config(action="show", output="json")
        stdout = output.getvalue()
        assert result == 0
        # JSON output should be parseable
        import json

        data = json.loads(stdout)
        assert isinstance(data, dict)

    def test_config_output_toml(self, project_dir: str, capture: Callable) -> None:
        """Test jac config with TOML output format."""
        with capture() as output:
            result = config_cmd.config(action="show", output="toml")
        stdout = output.getvalue()
        assert result == 0
        # TOML output should contain section markers
        assert "[" in stdout

    def test_config_no_project(self, tmp_path: Path, capture: Callable) -> None:
        """Test jac config behavior when no jac.toml exists."""
        original_cwd = os.getcwd()
        os.chdir(tmp_path)
        try:
            with capture() as output:
                config_cmd.config(action="path")
            stdout = output.getvalue()
            # The config path command shows the expected path even if file doesn't exist
            # Just verify it shows a path ending in jac.toml
            assert "jac.toml" in stdout
        finally:
            os.chdir(original_cwd)


def _run_jac_check(test_dir: str, ignore_pattern: str = "") -> int:
    """Run jac check and return file count."""
    captured_stdout = io.StringIO()
    captured_stderr = io.StringIO()
    old_stdout = sys.stdout
    old_stderr = sys.stderr
    sys.stdout = captured_stdout
    sys.stderr = captured_stderr

    try:
        analysis.check([test_dir], ignore=ignore_pattern)
        stdout = captured_stdout.getvalue()
        stderr = captured_stderr.getvalue()
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr

    match = re.search(r"Checked (\d+)", stdout + stderr)
    return int(match.group(1)) if match else 0


def test_jac_grammar(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that jac grammar command extracts grammar rules."""
    with capture_stdout() as output:
        result = analysis.grammar()

    stdout_value = output.getvalue()
    assert result == 0, "grammar command should exit with code 0"
    # Should contain grammar rule definitions (::= for EBNF)
    assert "::=" in stdout_value, "EBNF output should contain rule definitions"
    # Should contain well-known rule names from the parser
    assert "module" in stdout_value, "Grammar should contain 'module' rule"


def test_jac_grammar_lark(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that jac grammar --lark outputs Lark format."""
    with capture_stdout() as output:
        result = analysis.grammar(lark=True)

    stdout_value = output.getvalue()
    assert result == 0, "grammar --lark command should exit with code 0"
    assert len(stdout_value) > 0, "Lark output should not be empty"


def test_jac_cli_check_ignore_patterns(fixture_path: Callable[[str], str]) -> None:
    """Test --ignore flag with exact pattern matching (combined patterns)."""
    test_dir = fixture_path("deep")
    result_count = _run_jac_check(test_dir, "deeper,one_lev_dup.jac,one_lev.jac,mycode")
    # Only mycode.jac is checked; all other files are ignored
    assert result_count == 1


class TestCleanCommand:
    """Tests for the jac clean CLI command."""

    @staticmethod
    def _create_project(tmpdir: str) -> str:
        """Create a minimal jac project structure for testing."""
        project_path = os.path.join(tmpdir, "testproj")
        os.makedirs(project_path, exist_ok=True)

        # Create minimal jac.toml
        toml_content = """\
[project]
name = "testproj"
version = "0.1.0"
"""
        with open(os.path.join(project_path, "jac.toml"), "w") as f:
            f.write(toml_content)

        # Create .jac directory structure
        os.makedirs(os.path.join(project_path, ".jac"), exist_ok=True)

        return project_path

    @staticmethod
    def _capture_output() -> tuple[
        io.StringIO, io.StringIO, "typing.TextIO", "typing.TextIO"
    ]:
        """Set up output capture and return (stdout_capture, stderr_capture, old_stdout, old_stderr)."""
        captured_stdout = io.StringIO()
        captured_stderr = io.StringIO()
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdout = captured_stdout
        sys.stderr = captured_stderr
        return captured_stdout, captured_stderr, old_stdout, old_stderr

    @staticmethod
    def _restore_output(
        old_stdout: "typing.TextIO", old_stderr: "typing.TextIO"
    ) -> None:
        """Restore original stdout/stderr."""
        sys.stdout = old_stdout
        sys.stderr = old_stderr

    @staticmethod
    def _reset_config() -> None:
        """Reset the global config cache to force rediscovery."""
        from jaclang.project import config as config_module

        config_module._config = None

    def test_clean_no_project(self) -> None:
        """Test jac clean fails when no jac.toml exists."""
        with tempfile.TemporaryDirectory() as tmpdir:
            original_cwd = os.getcwd()
            os.chdir(tmpdir)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                result = project.clean(force=True)
                stderr = captured_stderr.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 1
            assert "No jac.toml found" in stderr

    def test_clean_nothing_to_clean(self) -> None:
        """Test jac clean when no build artifacts exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)

            # Remove the .jac/data directory if it exists (keep only cache from build)
            data_dir = os.path.join(project_path, ".jac", "data")
            if os.path.exists(data_dir):
                import shutil

                shutil.rmtree(data_dir)

            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                result = project.clean(force=True)
                stdout = captured_stdout.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 0
            assert "Nothing to clean" in stdout

    def test_clean_data_directory(self) -> None:
        """Test jac clean removes the data directory by default."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)

            # Create .jac/data directory with some files
            data_dir = os.path.join(project_path, ".jac", "data")
            os.makedirs(data_dir, exist_ok=True)
            test_file = os.path.join(data_dir, "test.db")
            with open(test_file, "w") as f:
                f.write("test data")

            assert os.path.exists(data_dir)

            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                result = project.clean(force=True)
                stdout = captured_stdout.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 0
            assert "Removed data:" in stdout
            assert not os.path.exists(data_dir)

    def test_clean_cache_directory(self) -> None:
        """Test jac clean --cache removes the cache directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)

            # jac create already creates .jac/cache, but let's ensure it has content
            cache_dir = os.path.join(project_path, ".jac", "cache")
            os.makedirs(cache_dir, exist_ok=True)
            test_file = os.path.join(cache_dir, "cached.pyc")
            with open(test_file, "w") as f:
                f.write("cached bytecode")

            assert os.path.exists(cache_dir)

            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                result = project.clean(cache=True, force=True)
                stdout = captured_stdout.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 0
            assert "Removed cache:" in stdout
            assert not os.path.exists(cache_dir)

    def test_clean_all_directories(self) -> None:
        """Test jac clean --all removes all build artifact directories."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)

            # Create all .jac subdirectories with content
            jac_dir = os.path.join(project_path, ".jac")
            dirs_to_create = ["data", "cache", "venv", "client"]
            for dir_name in dirs_to_create:
                dir_path = os.path.join(jac_dir, dir_name)
                os.makedirs(dir_path, exist_ok=True)
                # Add a file to each directory
                with open(os.path.join(dir_path, "test.txt"), "w") as f:
                    f.write("test")

            for dir_name in dirs_to_create:
                assert os.path.exists(os.path.join(jac_dir, dir_name))

            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                # Note: 'all' is a Python keyword, so we use **kwargs
                result = project.clean(**{"all": True, "force": True})
                stdout = captured_stdout.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 0
            assert "Clean completed successfully" in stdout

            # Verify all directories are removed
            for dir_name in dirs_to_create:
                assert not os.path.exists(os.path.join(jac_dir, dir_name))

    def test_clean_multiple_specific_directories(self) -> None:
        """Test jac clean with multiple specific flags."""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)

            # Create .jac subdirectories with content
            jac_dir = os.path.join(project_path, ".jac")
            data_dir = os.path.join(jac_dir, "data")
            cache_dir = os.path.join(jac_dir, "cache")
            venv_dir = os.path.join(jac_dir, "venv")

            for dir_path in [data_dir, cache_dir, venv_dir]:
                os.makedirs(dir_path, exist_ok=True)
                with open(os.path.join(dir_path, "test.txt"), "w") as f:
                    f.write("test")

            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            captured_stdout, captured_stderr, old_stdout, old_stderr = (
                self._capture_output()
            )
            try:
                result = project.clean(data=True, cache=True, force=True)
                stdout = captured_stdout.getvalue()
            finally:
                self._restore_output(old_stdout, old_stderr)
                os.chdir(original_cwd)
                self._reset_config()
            assert result == 0
            assert "Removed data:" in stdout
            assert "Removed cache:" in stdout
            # Venv should NOT be removed
            assert os.path.exists(venv_dir)
            assert not os.path.exists(data_dir)
            assert not os.path.exists(cache_dir)


def test_error_traceback_shows_source_code(fixture_path: Callable[[str], str]) -> None:
    """Test that runtime errors show source code context and line numbers."""
    # Test that import errors show the problematic line with context
    captured_stdout = io.StringIO()
    captured_stderr = io.StringIO()
    old_stdout = sys.stdout
    old_stderr = sys.stderr
    sys.stdout = captured_stdout
    sys.stderr = captured_stderr

    try:
        result = execution.run(fixture_path("import_error_traceback.jac"))
        stderr = captured_stderr.getvalue()
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr

    # Should exit with error
    assert result == 1, "run command should exit with code 1 on import error"

    # Should show the error message
    assert "Error" in stderr, "stderr should contain 'Error'"
    assert (
        "attempted relative import" in stderr
        or "ImportError" in stderr
        or "__package__" in stderr
    ), "stderr should contain import error message"

    # Should show the source code line that caused the error
    assert "import from .nonexistent_module" in stderr, (
        "stderr should show the problematic import statement"
    )

    # Should show the file path and line number
    assert "import_error_traceback.jac" in stderr, (
        "stderr should contain the source file name"
    )
    assert ":7" in stderr or "line 7" in stderr, (
        "stderr should indicate line number 7 where the error occurred"
    )


def test_syntax_error_pretty_print(fixture_path: Callable[[str], str]) -> None:
    """Test that syntax errors are pretty printed correctly."""
    from jaclang.jac0core.program import JacProgram

    program = JacProgram()
    program.compile(fixture_path("test_syntax_err.jac"))
    assert len(program.errors_had) == 1, (
        f"Expected 1 error with improved error reporting, got {len(program.errors_had)}"
    )
    # The new error reporting gives a single, clear error message
    # pointing to exactly where the problem is
    _assert_error_pretty_found(
        """
        2 |
        3 | walker w {
        4 |     can foo {
          |             ^
        5 |         print "Missing semicolon"
        6 |     }
    """,
        program.errors_had[0].pretty_print(),
    )
