"""Test SymTable Link Pass."""

import os

from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


class SymTabLinkPassTests(TestCase):
    """Test pass module."""

    # Need change
    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_no_dupl_symbols(self) -> None:
        """Basic test for pass."""
        file_path = os.path.join(
            os.path.dirname(__file__),
            "fixtures",
            "symtab_link_tests",
            "no_dupls.jac",
        )
        mod = JacProgram().build(file_path)
        self.assertEqual(
            len(mod.sym_tab.names_in_scope.values()),
            3,
        )
        for i in ["[Symbol(a,", "Symbol(Man,", "Symbol(p,"]:
            self.assertIn(
                i,
                str(mod.sym_tab.names_in_scope.values()),
            )
        # TODO: def use is called on single file so this breaks
        # Def Use pass will go away with full type checking
        # self.assertEqual(
        #     len(mod.sym_tab.names_in_scope["a"].uses), 4
        # )
        # self.assertEqual(
        #     len(
        #         list(
        #             mod.sym_tab.kid_scope[0]
        #             .kid_scope[0]
        #             .kid_scope[0]
        #             .kid_scope[0]
        #             .inherited_scope[0]
        #             .base_symbol_table.names_in_scope.values()
        #         )[0].uses,
        #     ),
        #     3,
        # )

    def test_package(self) -> None:
        """Test package."""
        file_path = os.path.join(
            os.path.dirname(__file__),
            "fixtures",
            "symtab_link_tests",
            "main.jac",
        )
        prog = JacProgram()
        prog.compile(file_path)
        self.assertEqual(prog.errors_had, [])
        self.assertEqual(prog.warnings_had, [])
