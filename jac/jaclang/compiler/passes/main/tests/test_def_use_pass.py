"""Test pass module."""

from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


class DefUsePassTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_def_uses(self) -> None:
        """Basic test for pass."""
        state = JacProgram().compile(
            file_path=self.fixture_abs_path("defs_and_uses.jac")
        )
        uses = [i.uses for i in state.sym_tab.kid_scope[0].names_in_scope.values()]
        self.assertEqual(len(uses[0]), 1)
        self.assertEqual(len(uses[1]), 1)
        self.assertIn("output", [uses[0][0].sym_name, uses[1][0].sym_name])
        self.assertIn("message", [uses[0][0].sym_name, uses[1][0].sym_name])
