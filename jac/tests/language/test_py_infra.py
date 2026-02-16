"""Tests requiring Python-only infrastructure.

Covers py2jac conversion (PyastBuildPass), tempfile, subprocess,
sys.stderr redirect, os.chdir, xfail, etc.  All simple "run fixture
and check stdout" tests live in test_language.jac.
"""

import io
import os
import subprocess
import sys
import tempfile
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path
from unittest.mock import patch

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution, transform  # type: ignore[attr-defined]
from jaclang.jac0core.bccache import get_global_cache_dir
from jaclang.jac0core.program import JacProgram
from jaclang.runtimelib.utils import read_file_with_encoding


@pytest.fixture(autouse=True)
def setup_jac_runtime(
    fixture_path: Callable[[str], str],
    fresh_jac_context: Path,  # Provides isolated Jac context
) -> Generator[None, None, None]:
    """Set up and tear down Jac runtime for each test."""
    Jac.attach_program(JacProgram())
    yield


# ── PyastBuildPass / py2jac tests ────────────────────────────────────────────


def test_pyfunc_1(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_1.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "def greet2(**kwargs: Any) -> None {" in output
    assert output.count("with entry {") == 14
    assert "assert (x == 5) , 'x should be equal to 5';" in output
    assert "if not (x == y) {" in output
    assert "squares_dict = {x: (x ** 2) for x in numbers};" in output
    assert '\n"""Say hello"""\n@my_decorator\n\n def say_hello() -> object {' in output


def test_pyfunc_2(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_2.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "class X {\n    with entry {\n        a_b = 67;" in output
    assert "br = b'Hello\\\\\\\\nWorld'" in output
    assert "class Circle {\n    def init(self: Circle, radius: float" in output
    assert "`node = 90;\n    print(`node);\n" in output


def test_pyfunc_3(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "pyfunc_3.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "if (0 <= x <= 5) {" in output
    assert "  case _:\n" in output
    assert " case Point(x = int(a), y = 0):\n" in output
    assert "class Sample {\n    def init" in output


def test_py2jac(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "match Container(inner=Inner(x=a, y=b)) {\n" in output
    assert "case Container(inner = Inner(x = a, y = 0)):\n" in output
    assert "case Container(inner = Inner(x = a, y = b)):\n" in output
    assert "case _:\n" in output


def test_py2jac_params(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_params.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert (
        "def isinstance(`obj: object, class_or_tuple: _ClassInfo, /) -> bool {"
        in output
    )
    assert (
        "def len(`obj: Sized, astt: object, /, z: int, j: str, a: int = 90) -> int {"
        in output
    )


def test_py2jac_empty_file(fixture_path: Callable[[str], str]) -> None:
    """Test py ast to Jac ast conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_empty.py")
    with open(py_out_path) as f:
        file_source = f.read()
        converted_ast = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out
    assert isinstance(converted_ast, ast.Module)


def test_py2jac_augassign_and_doc(fixture_path: Callable[[str], str]) -> None:
    """Ensure augmented assigns avoid redecl and nested docstrings terminate."""
    import ast as py_ast

    import jaclang.jac0core.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_augassign_doc.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "x += 2;" in output  # augmented assign should not emit `let`
    assert '"""inner doc"""; def inner()' in output  # docstring should end before def


def test_py2jac_reassign_semantics(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that py2jac preserves variable reassignment semantics.

    This test catches the bug where py2jac incorrectly uses 'let' for
    variable reassignments inside loops/conditionals, which creates
    shadowed variables instead of modifying the outer scope variable.
    """
    import ast as py_ast

    import jaclang.jac0core.unitree as ast
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py2jac_reassign.py")
    with open(py_out_path) as f:
        file_source = f.read()
        jac_code = PyastBuildPass(
            ir_in=ast.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=ast.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()

    # Key check: reassignments should NOT use 'let'
    # Wrong: "let found = True;" inside the if block
    # Right: "found = True;" inside the if block
    assert "let found = True" not in jac_code, (
        "py2jac bug: 'let' used for reassignment in loop - "
        "this creates a shadowed variable instead of reassigning"
    )
    assert (
        "let status = " not in jac_code.split("let status = ")[2]
        if jac_code.count("let status = ") > 1
        else True
    ), "py2jac bug: 'let' used for reassignment in conditional"

    # Execute the converted code and verify it produces correct results
    with capture_stdout() as captured_output:
        Jac.jac_import(
            target="py2jac_reassign",
            base_path=fixture_path("./"),
        )
    stdout_value = captured_output.getvalue()
    assert "All tests passed!" in stdout_value, (
        f"Converted Jac code produced wrong output. "
        f"This likely means py2jac created shadowed variables. Output: {stdout_value}"
    )


def test_py_namedexpr(fixture_path: Callable[[str], str]) -> None:
    """Ensure NamedExpr nodes are converted to AtomUnit."""
    import ast as py_ast

    import jaclang.jac0core.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py_namedexpr.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "(x := 10)" in output


def test_py_bool_parentheses(fixture_path: Callable[[str], str]) -> None:
    """Ensure boolean expressions preserve parentheses during conversion."""
    import ast as py_ast

    import jaclang.jac0core.unitree as uni
    from jaclang.compiler.passes.main import PyastBuildPass

    py_out_path = os.path.join(fixture_path("./"), "py_bool_expr.py")
    with open(py_out_path) as f:
        file_source = f.read()
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path),
            ),
            prog=JacProgram(),
        ).ir_out.unparse()
    assert "(prev_token_index is None)" in output
    assert "(next_token_index is None)" in output
    assert "(tok[0] > change_end_line)" in output
    assert "(tok[0] == change_end_line)" in output
    assert "(tok[1] > change_end_char)" in output


def test_funccall_genexpr_py2jac(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test py2jac conversion of function call with generator expression."""
    py_file_path = f"{fixture_path('funccall_genexpr.py')}"
    with capture_stdout() as captured_output:
        transform.py2jac(py_file_path)
    stdout_value = captured_output.getvalue()
    assert "result = total((x * x) for x in range(5));" in stdout_value


# ── Tests requiring special Python infrastructure ────────────────────────────


def test_deep_imports_interp_mode(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    Jac.set_base_path(fixture_path("./"))
    Jac.attach_program(
        JacProgram(),
    )
    # Clear any cached module from previous test runs
    for mod_name in list(sys.modules.keys()):
        if "deep_import_interp" in mod_name:
            del sys.modules[mod_name]
    # Delete bytecode cache files to force recompilation (from global cache dir)
    cache_dir = get_global_cache_dir()
    if cache_dir.exists():
        for cache_file in cache_dir.glob("*deep_import*"):
            cache_file.unlink()

    with capture_stdout() as captured_output:
        Jac.jac_import("deep_import_interp", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    # Main module must be registered in the hub; transitive imports may also
    # appear when their bytecode isn't cached yet, so only assert presence.
    assert fixture_path("deep_import_interp.jac") in Jac.get_program().mod.hub
    assert "one level deeperslHello World!" in stdout_value

    Jac.set_base_path(fixture_path("./"))
    Jac.attach_program(
        (prog := JacProgram()),
    )
    prog.compile(fixture_path("./deep_import_interp.jac"))
    # as we use jac_import, only main module should be in the hub
    assert len(Jac.get_program().mod.hub.keys()) == 1


def test_deep_outer_imports_from_loc(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        os.chdir(fixture_path("./deep/deeper/"))
        execution.run("deep_outer_import.jac")
    stdout_value = captured_output.getvalue()
    assert "one level deeperslHello World!" in stdout_value
    assert (
        "module 'jaclang.tests.fixtures.pyfunc' from " in stdout_value
        or "module 'pyfunc' from " in stdout_value
    )


@pytest.mark.xfail(reason="TODO: Support symtable for inheritance")
def test_inherit_baseclass_sym(examples_path: Callable[[str], str]) -> None:
    """Basic test for symtable support for inheritance."""
    mypass = JacProgram().compile(examples_path("guess_game/guess_game3.jac"))
    table = None
    for i in mypass.sym_tab.kid_scope:
        if i.scope_name == "GuessTheNumberGame":
            for j in i.kid_scope:
                if j.scope_name == "play":
                    table = j
                    break
            break
    assert table is not None
    assert table.lookup("attempts") is not None


def test_list_methods(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test list_modules, list_walkers, list_nodes, and list_edges."""
    Jac.set_base_path(fixture_path("."))
    sys.modules.pop("foo", None)
    sys.modules.pop("bar", None)
    with capture_stdout() as captured_output:
        Jac.jac_import("foo", base_path=fixture_path("."))

    stdout_value = captured_output.getvalue()

    assert "Module: foo" in stdout_value
    assert "Module: bar" in stdout_value
    assert "Walkers in bar:\n  - Walker: bar_walk" in stdout_value
    assert "Nodes in bar:\n  - Node: Item" in stdout_value
    assert "Edges in bar:\n  - Edge: Link" in stdout_value
    assert "Item value: 0" in stdout_value
    assert "Created 5 items." in stdout_value


def test_walker_dynamic_update(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
    fresh_jac_context: Path,
) -> None:
    """Test dynamic update of a walker during runtime."""
    sys.modules.pop("bar", None)
    bar_file_path = fixture_path("bar.jac")
    update_file_path = fixture_path("walker_update.jac")
    with capture_stdout() as captured_output:
        execution.enter(
            filename=bar_file_path,
            entrypoint="bar_walk",
            args=[],
        )
    stdout_value = captured_output.getvalue()
    expected_output = "Created 5 items."
    assert expected_output in stdout_value.split("\n")
    # Define the new behavior to be added (using entry since exits are deferred
    # and won't run when disengage is called during child traversal)
    new_behavior = """
    # New behavior added during runtime
    can announce with Root entry {
        "bar_walk has been updated with new behavior!" |> print;
        }
    }
    """

    # Backup the original file content
    with open(bar_file_path) as bar_file:
        original_content = bar_file.read()

    # Update the bar.jac file with new behavior
    with open(bar_file_path, "r+") as bar_file:
        content = bar_file.read()
        last_brace_index = content.rfind("}")
        if last_brace_index != -1:
            updated_content = content[:last_brace_index] + new_behavior
            bar_file.seek(0)
            bar_file.write(updated_content)
            bar_file.truncate()

    with capture_stdout() as captured_output:
        try:
            # Reset state for dynamic update test
            Jac.loaded_modules.clear()
            Jac.attach_program(JacProgram())
            execution.run(
                filename=update_file_path,
            )
            stdout_value = captured_output.getvalue()
            expected_output = "bar_walk has been updated with new behavior!"
            assert expected_output in stdout_value.split("\n")
        finally:
            # Restore the original content of bar.jac
            with open(bar_file_path, "w") as bar_file:
                bar_file.write(original_content)


# Helper method to create files within tests
def create_temp_jac_file(
    content: str, dir_path: str, filename: str = "test_mod.jac"
) -> str:
    """Create a temporary Jac file in a specific directory."""
    full_path = os.path.join(dir_path, filename)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w") as f:
        f.write(content)
    return full_path


def test_import_from_site_packages(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing a Jac module from simulated site-packages."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Simulate site-packages directory structure
        mock_site_dir = os.path.join(tmpdir, "site-packages")
        os.makedirs(mock_site_dir)

        # Create a module within the simulated site-packages
        site_mod_content = 'with entry { "Site package module loaded!" |> print; }'
        create_temp_jac_file(site_mod_content, mock_site_dir, "site_pkg_mod.jac")

        # Create the importing script in the main temp directory
        importer_content = "import site_pkg_mod;"
        _ = create_temp_jac_file(importer_content, tmpdir, "importer_site.jac")
        with patch("site.getsitepackages", return_value=[mock_site_dir]):
            with capture_stdout() as captured_output:
                original_cwd = os.getcwd()
                try:
                    Jac.jac_import("importer_site", base_path=tmpdir)
                finally:
                    os.chdir(original_cwd)

            stdout_value = captured_output.getvalue()
            assert "Site package module loaded!" in stdout_value


def test_import_from_jacpath(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test importing a Jac module from JACPATH."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Simulate JACPATH directory
        jacpath_dir = os.path.join(tmpdir, "jaclibs")
        os.makedirs(jacpath_dir)

        # Create a module in the JACPATH directory
        jacpath_mod_content = 'with entry { "JACPATH module loaded!" |> print; }'
        create_temp_jac_file(jacpath_mod_content, jacpath_dir, "jacpath_mod.jac")

        # Create the importing script in a different location
        script_dir = os.path.join(tmpdir, "scripts")
        os.makedirs(script_dir)
        importer_content = "import jacpath_mod;"
        _ = create_temp_jac_file(importer_content, script_dir, "importer.jac")

        # Set JACPATH environment variable and run
        original_jacpath = os.environ.get("JACPATH")
        os.environ["JACPATH"] = jacpath_dir
        with capture_stdout() as captured_output:
            original_cwd = os.getcwd()
            os.chdir(script_dir)
            try:
                execution.run("importer.jac")
            finally:
                os.chdir(original_cwd)
                # Clean up environment variable
                if original_jacpath is None:
                    if "JACPATH" in os.environ:
                        del os.environ["JACPATH"]
                else:
                    os.environ["JACPATH"] = original_jacpath

        stdout_value = captured_output.getvalue()
        assert "JACPATH module loaded!" in stdout_value


def test_import_jac_from_py(
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        from .fixtures import jac_from_py

        jac_from_py.main()

    stdout_value = captured_output.getvalue()
    assert (
        stdout_value == "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
        "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n"
    )


def test_here_visitor_error(fixture_path: Callable[[str], str]) -> None:
    """Test visitor, here keyword usage in jaclang."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    try:
        result = execution.run(fixture_path("here_usage_error.jac"))
    finally:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
    assert result == 1
    stdout_value = captured_output.getvalue()
    assert "'here' is not defined" in stdout_value


def test_by_operator(fixture_path: Callable[[str], str]) -> None:
    """Test 'by' operator raises NotImplementedError."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    sys.stderr = captured_output
    try:
        result = execution.run(fixture_path("by_operator.jac"))
    finally:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
    assert result == 1
    stdout_value = captured_output.getvalue()
    assert "by" in stdout_value.lower()
    assert "not" in stdout_value.lower()
    assert "implemented" in stdout_value.lower()


def test_sitecustomize_meta_importer():
    """Verify Jac modules importable without importing jaclang."""
    with tempfile.TemporaryDirectory() as tmpdir:
        Path(tmpdir, "mymod.jac").write_text('with entry {print("via meta");}')
        env = os.environ.copy()
        project_root = Path(__file__).resolve().parents[2]
        env["PYTHONPATH"] = os.pathsep.join([str(project_root), tmpdir])
        proc = subprocess.run(
            [sys.executable, "-c", "import mymod"],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env,
        )
        assert proc.returncode == 0, proc.stderr
        assert proc.stdout.strip() == "via meta"


# ── read_file_with_encoding tests ────────────────────────────────────────────


def test_read_file_with_encoding_utf8():
    """Test reading UTF-8 encoded file."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f:
        test_content = "Hello, 世界! 🌍 Testing UTF-8 encoding."
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_utf16():
    """Test reading UTF-16 encoded file when UTF-8 fails."""
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-16") as f:
        test_content = "Hello, 世界! UTF-16 encoding test."
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_utf8_bom():
    """Test reading UTF-8 with BOM encoded file."""
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-8-sig") as f:
        test_content = "Hello, UTF-8 BOM test! 🚀"
        f.write(test_content)
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert result == test_content
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_binary_file_fallback():
    """Test reading binary file falls back to latin-1."""
    with tempfile.NamedTemporaryFile(delete=False) as f:
        binary_data = bytes([0xFF, 0xFE, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
        f.write(binary_data)
        f.flush()
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)
        assert isinstance(result, str)
        assert len(result) > 0
    finally:
        os.unlink(temp_path)


def test_read_file_with_encoding_special_characters():
    """Test reading file with various special characters."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f:
        test_content = "Special chars: åäö ñ ü ç é\nSymbols: ©®™ §¶†‡•\nMath: ∑∏∫√±≤≥≠\nArrows: ←→↑↓↔\nEmoji: 😀😍🎉🔥💯\n"
        f.write(test_content)
        f.flush()
        temp_path = f.name

    try:
        result = read_file_with_encoding(temp_path)

        assert result == test_content
        assert "åäö" in result
        assert "©®™" in result
        assert "∑∏∫" in result
        assert "😀😍" in result
    finally:
        os.unlink(temp_path)
