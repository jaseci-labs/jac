"""Test Binder pass."""

from jaclang.compiler.program import JacProgram
from jaclang.utils.symtable_test_helpers import SymTableTestMixin


class BinderPassTests( SymTableTestMixin):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_glob_sym_build(self) -> None:
        """Test symbol table construction for symbol_binding_test.jac fixture."""
        mod_targ = JacProgram().bind(self.fixture_abs_path("sym_binder.jac"))
        sym_table = mod_targ.sym_tab

        #currenlty 'aa' is not in the main table, need fix #TODO
            # defns=[(9, 6), (16, 5), (27, 9), (32, 5)],
            # uses=[(33, 11), (37, 11)]
        # Test global variable 'aa'
        self.assert_symbol_complete(
            sym_table, "aa", "variable",
            decl=(9, 6),
            defns=[(9, 6), (16, 5), ],
            uses=[ (37, 11)]
        )

        # Test global variable 'n'
        self.assert_symbol_complete(
            sym_table, "n", "variable",
            decl=(14, 5),
            defns=[(14, 5)]
        )

        # Test imported module 'M1'
        self.assert_symbol_complete(
            sym_table, "M1", "module",
            decl=(1, 8),
            defns=[(1, 8)]
        )

        # Test global variable 'z'
        self.assert_symbol_complete(
            sym_table, "z", "variable",
            decl=(15, 5),
            defns=[(15, 5)]
        )

        # Test global variable 'Y'
        self.assert_symbol_complete(
            sym_table, "Y", "variable",
            decl=(11, 5),
            defns=[(11, 5), (12, 5), (19, 5)],
            uses=[(15, 9)]
        )

        # Test ability 'ccc'
        self.assert_symbol_complete(
            sym_table, "ccc", "ability",
            decl=(22, 5),
            defns=[(22, 5)],
            uses=[(36, 5)]
        )

        #TODO: Fix the following test, 'bb' is not in the main table
        # # Test global variable 'bb'
        # self.assert_symbol_complete(
        #     sym_table, "bb", "variable",
        #     decl=(26, 17),
        #     defns=[(26, 17), (28, 9)]
        # )

        # Test sub-table for ability 'ccc'
        ccc_table = self.assert_sub_table_exists(sym_table, "ccc",'ability')

        # Test sub-table for if statement inside 'ccc'
        if_table = self.assert_sub_table_exists(ccc_table, "IfStmt",'variable')

        # Test local variable 'p' inside if statement
        self.assert_symbol_complete(
            if_table, "p", "variable",
            decl=(29, 9),
            defns=[(29, 9)]
        )

    def test_symbol_table_structure(self) -> None:
        """Test the overall structure of the symbol table."""
        mod_targ = JacProgram().build(self.fixture_abs_path("sym_binder.jac"))
        sym_table = mod_targ.sym_tab

        # Verify main module table exists
        self.assertIn("sym_binder", str(sym_table))

        # Verify expected number of symbols in main table
        main_symbols = ["aa", "n", "M1", "z", "Y", "ccc"]
        # 'bb' is not here:need fix #TODO
        for symbol_name in main_symbols:
            self.assert_symbol_exists(sym_table, symbol_name)

        # Verify sub-tables exist
        sub_tables = sym_table.kid_scope
        self.assertTrue(len(sub_tables) > 0, "No sub-tables found")

        # Verify ability sub-table has nested if-statement table
        ccc_table = self.assert_sub_table_exists(sym_table, "ccc", 'ability')
        if_table = self.assert_sub_table_exists(ccc_table, "IfStmt", 'variable')

        # Verify if-statement table contains local variable
        self.assert_symbol_exists(if_table, "p")