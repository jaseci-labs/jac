"""Test jac.lark grammar for Shift/Reduce errors."""

import os

import jaclang
from jaclang.utils.test import TestCase

try:
    from lark import Lark
    from lark.exceptions import GrammarError
except ImportError:  # pragma: no cover - lark should be installed for tests
    Lark = None  # type: ignore
    GrammarError = Exception


class TestJacGrammar(TestCase):
    """Check that jac.lark has no shift/reduce conflicts."""

    def test_no_shift_reduce_errors(self) -> None:
        """Ensure jac.lark parses with strict mode."""
        if Lark is None:
            self.fail("lark library not available")

        lark_path = os.path.join(os.path.dirname(jaclang.__file__), "compiler/jac.lark")
        with open(lark_path, "r", encoding="utf-8") as f:
            grammar = f.read()

        # Lark's strict mode raises GrammarError on conflicts
        try:
            Lark(grammar, parser="lalr", start="start", strict=True)
        except GrammarError as e:  # pragma: no cover - fail if conflicts
            self.fail(f"Shift/reduce conflicts detected: {e}")