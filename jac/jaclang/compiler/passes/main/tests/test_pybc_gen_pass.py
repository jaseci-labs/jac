"""Test pass module."""

import marshal

import pytest

from jaclang.compiler.program import JacProgram


def test_simple_bcgen(fixture_path: callable) -> None:
    """Basic test for pass."""
    jac_code = JacProgram().compile(
        file_path=fixture_path("func.jac"),
    )
    try:
        marshal.loads(jac_code.gen.py_bytecode)
        assert True
    except ValueError:
        pytest.fail("Invalid bytecode generated")
