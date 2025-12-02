"""Test jac.lark grammar for Shift/Reduce errors."""

import os

import pytest

import jaclang

try:
    from lark import Lark
    from lark.exceptions import GrammarError
except ImportError:  # pragma: no cover - lark should be installed for tests
    Lark = None  # type: ignore
    GrammarError = Exception


def test_no_shift_reduce_errors() -> None:
    """Ensure jac.lark parses with strict mode."""
    if Lark is None:
        pytest.fail("lark library not available")

    lark_path = os.path.join(os.path.dirname(jaclang.__file__), "compiler/jac.lark")
    with open(lark_path, encoding="utf-8") as f:
        grammar = f.read()

    # Lark's strict mode raises GrammarError on conflicts
    try:
        Lark(grammar, parser="lalr", start="start", strict=True)
    except GrammarError as e:  # pragma: no cover - fail if conflicts
        pytest.fail(f"Shift/reduce conflicts detected: {e}")
