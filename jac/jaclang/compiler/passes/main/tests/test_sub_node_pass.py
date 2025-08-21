"""Test sub node pass module."""

from jaclang.compiler.passes import UniPass
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


class SubNodePassTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_sub_node_pass(self) -> None:
        """Basic test for pass."""
        code_gen = (out := JacProgram()).compile(
            file_path=self.examples_abs_path("manual_code/circle.jac")
        )
        for i in code_gen.kid[1].kid:
            for k, v in i._sub_node_tab.items():
                for n in v:
                    self.assertIn(n, UniPass.get_all_sub_nodes(i, k, brute_force=True))
        self.assertFalse(out.errors_had)
