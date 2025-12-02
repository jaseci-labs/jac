"""Test ast build pass module."""

import io
import sys
from collections.abc import Callable

import pytest

from jaclang.compiler.passes.main import PreDynamoPass
from jaclang.compiler.program import JacProgram, py_code_gen
from jaclang.settings import settings


@pytest.fixture(autouse=True)
def setup_predynamo():
    """Set up and tear down predynamo settings."""
    settings.predynamo_pass = True
    yield
    settings.predynamo_pass = False
    # Remove PreDynamoPass from global py_code_gen list if it was added
    if PreDynamoPass in py_code_gen:
        py_code_gen.remove(PreDynamoPass)


def test_predynamo_where_assign(fixture_path: Callable[[str], str]) -> None:
    """Test torch.where transformation."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    settings.predynamo_pass = True
    code_gen = JacProgram().compile(fixture_path("predynamo_where_assign.jac"))
    sys.stdout = sys.__stdout__
    assert "torch.where" in code_gen.unparse()


def test_predynamo_where_return(fixture_path: Callable[[str], str]) -> None:
    """Test torch.where transformation."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    code_gen = JacProgram().compile(fixture_path("predynamo_where_return.jac"))
    sys.stdout = sys.__stdout__
    assert "torch.where" in code_gen.unparse()


def test_predynamo_fix3(fixture_path: Callable[[str], str]) -> None:
    """Test torch.where transformation."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    code_gen = JacProgram().compile(fixture_path("predynamo_fix3.jac"))
    sys.stdout = sys.__stdout__
    unparsed_code = code_gen.unparse()
    assert "__inv_freq = torch.where(" in unparsed_code
    assert (
        "self.register_buffer('inv_freq', __inv_freq, persistent=False);"
        in unparsed_code
    )
