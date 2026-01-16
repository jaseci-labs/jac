"""Test Jac reference examples."""

from __future__ import annotations

import ast
import io
import os
import re
import sys
from contextlib import redirect_stdout
from types import CodeType

import pytest

import jaclang
from jaclang import JacRuntime as Jac
from jaclang.pycore.program import JacProgram
from tests.fixtures_list import REFERENCE_JAC_FILES


def get_reference_jac_files() -> list[str]:
    """Get all .jac files from examples/reference directory.

    Uses a fixed list of files from fixtures_list.py for deterministic testing.
    To add new test files, update REFERENCE_JAC_FILES in tests/fixtures_list.py.
    """
    base_dir = os.path.dirname(os.path.dirname(jaclang.__file__))
    return [os.path.normpath(os.path.join(base_dir, f)) for f in REFERENCE_JAC_FILES]


def execute_and_capture_output(code: str | bytes | CodeType, filename: str = "") -> str:
    """Execute code and capture stdout."""
    f = io.StringIO()
    with redirect_stdout(f):
        exec(
            code,
            {
                "__file__": filename,
                "__name__": "__main__",
            },
        )
    return f.getvalue()


def normalize_function_addresses(text: str) -> str:
    """Normalize function memory addresses in output for consistent comparison."""
    return re.sub(r"<function (\w+) at 0x[0-9a-f]+>", r"<function \1 at 0x...>", text)


@pytest.fixture(autouse=True)
def reset_jac_runtime():
    """Reset Jac runtime before and after each test.

    Reference tests don't need persistence - they just test compilation
    and execution. Pass base_path=None to disable L3 persistence.
    """
    Jac.reset_machine(base_path=None)
    yield
    Jac.reset_machine(base_path=None)


@pytest.mark.parametrize("filename", get_reference_jac_files())
def test_reference_file(filename: str) -> None:
    """Test reference .jac file against its .py equivalent."""
    if "tests.jac" in filename or "check_statements.jac" in filename:
        pytest.skip("Skipping test file")
    if "by_expressions.jac" in filename:
        pytest.skip("Skipping by_expressions - by operator not yet implemented")
    if "semstrings.jac" in filename:
        pytest.skip("Skipping semstrings - byllm not installed")

    try:
        jacast = JacProgram().compile(filename)
        py_ast = jacast.gen.py_ast[0]
        assert isinstance(py_ast, ast.Module)
        code_obj = compile(
            source=py_ast,
            filename=jacast.loc.mod_path,
            mode="exec",
        )
        output_jac = execute_and_capture_output(code_obj, filename=filename)
        Jac.reset_machine(
            base_path=None
        )  # Keep persistence disabled between .jac and .py runs

        # Clear byllm modules from cache
        sys.modules.pop("byllm", None)
        sys.modules.pop("byllm.lib", None)

        py_filename = filename.replace(".jac", ".py")
        with open(py_filename) as file:
            code_content = file.read()
        output_py = execute_and_capture_output(code_content, filename=py_filename)

        # Normalize function addresses before comparison
        output_jac = normalize_function_addresses(output_jac)
        output_py = normalize_function_addresses(output_py)

        print(f"\nJAC Output:\n{output_jac}")
        print(f"\nPython Output:\n{output_py}")

        assert len(output_py) > 0
        for i in output_py.split("\n"):
            assert i in output_jac
        for i in output_jac.split("\n"):
            assert i in output_py
        assert len(output_jac.split("\n")) == len(output_py.split("\n"))

    except Exception as e:
        raise e
