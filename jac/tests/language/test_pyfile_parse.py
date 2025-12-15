"""Ensure all Jaclang Python sources can be parsed via PyastBuildPass."""

from __future__ import annotations

import ast as py_ast
from pathlib import Path

import pytest

import jaclang
import jaclang.pycore.unitree as ast
from jaclang.compiler.passes.main import PyastBuildPass
from jaclang.pycore.program import JacProgram


def get_jaclang_python_files() -> list[str]:
    """Return all jaclang package .py files we expect to parse."""
    base = Path(jaclang.__file__).parent
    files: list[str] = []
    # Auto-generated parser files that are too large for py2jac conversion
    skip_files = {"jac_parser.py", "jac_lark.py"}
    for path in base.rglob("*.py"):
        if "__pycache__" in path.parts:
            continue
        if "vendor" in path.parts:
            continue
        if path.name in skip_files:
            continue
        files.append(str(path))
    return sorted(files)


@pytest.mark.parametrize("filename", get_jaclang_python_files())
def test_python_file_parses_with_pyast_build_pass(filename: str) -> None:
    """Every in-repo Python file should parse and unparse cleanly."""
    source = Path(filename).read_text()
    py_module = PyastBuildPass(
        ir_in=ast.PythonModuleAst(
            py_ast.parse(source),
            orig_src=ast.Source(source, filename),
        ),
        prog=JacProgram(),
    ).ir_out

    assert isinstance(py_module, ast.Module)
    # Should unparse without raising (formatting not required for this check)
    unparsed = py_module.unparse(requires_format=False)
    assert isinstance(unparsed, str)

    # Verify the generated Jac string can be parsed back by the Jac parser.
    # This catches issues like deeply nested expressions that cause recursion errors.
    prog = JacProgram.jac_str_formatter(source_str=unparsed, file_path=filename)
    assert not prog.errors_had, f"Failed to parse generated Jac code for {filename}"
