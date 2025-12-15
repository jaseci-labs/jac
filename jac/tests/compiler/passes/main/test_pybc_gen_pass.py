"""Test pass module."""

import marshal
from collections.abc import Callable

import pytest

from jaclang.compiler.program import JacProgram


def test_simple_bcgen(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    jac_code = JacProgram().compile(
        file_path=fixture_path("func.jac"),
    )
    bytecode = jac_code.gen.py_bytecode
    assert bytecode is not None, "Expected bytecode to be generated"
    try:
        marshal.loads(bytecode)
        assert True
    except ValueError:
        pytest.fail("Invalid bytecode generated")
