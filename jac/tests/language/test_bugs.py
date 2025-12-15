"""Test Jac language generally."""

from collections.abc import Callable

from jaclang.compiler.program import JacProgram


def test_impl_match_confusion_issue(fixture_path: Callable[[str], str]) -> None:
    """Basic test for symtable support for inheritance."""
    mypass = JacProgram()
    mypass.compile(fixture_path("impl_match_confused.jac"))
    assert len(mypass.errors_had) == 1
