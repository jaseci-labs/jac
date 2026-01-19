"""Test Jac reference examples."""

from __future__ import annotations

import ast
import io
import os
import re
import sys
from collections.abc import Generator
from contextlib import redirect_stdout
from pathlib import Path
from types import CodeType

import pytest

import jaclang
from jaclang import JacRuntime as Jac
from jaclang.pycore.program import JacProgram
from jaclang.pycore.runtime import JacRuntimeInterface
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
def reset_jac_runtime(fresh_jac_context: Path) -> Generator[Path, None, None]:
    """Reset Jac runtime before and after each test.

    Uses fresh_jac_context fixture to provide isolated state.
    Yields the tmp_path for use in tests.
    """
    yield fresh_jac_context


@pytest.mark.parametrize("filename", get_reference_jac_files())
def test_reference_file(filename: str, reset_jac_runtime: Path) -> None:
    """Test reference .jac file against its .py equivalent."""
    if "tests.jac" in filename or "check_statements.jac" in filename:
        pytest.skip("Skipping test file")
    if "by_expressions.jac" in filename:
        pytest.skip("Skipping by_expressions - by operator not yet implemented")
    if "semstrings.jac" in filename:
        pytest.skip("Skipping semstrings - byllm not installed")

    tmp_path = reset_jac_runtime

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

        # Clear state between .jac and .py runs
        # Remove user .jac modules from sys.modules so they don't interfere with .py run
        for mod in list(Jac.loaded_modules.values()):
            if not mod.__name__.startswith("jaclang."):
                sys.modules.pop(mod.__name__, None)
        Jac.loaded_modules.clear()
        Jac.attach_program(JacProgram())

        # Reset execution context with a NEW base path to get completely fresh storage
        if Jac.exec_ctx is not None:
            Jac.exec_ctx.mem.close()
        py_run_path = tmp_path / "py_run"
        py_run_path.mkdir(exist_ok=True)
        Jac.base_path_dir = str(py_run_path)
        Jac.exec_ctx = JacRuntimeInterface.create_j_context(user_root=None)

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
