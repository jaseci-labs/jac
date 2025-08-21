"""Symbol table testing helpers for Jaseci."""

from typing import Optional

from jaclang.compiler.unitree import Symbol, UniScopeNode
from jaclang.utils.test import TestCase


class SymTableTestMixin(TestCase):
    """Mixin class providing assertion methods for symbol table testing."""

    def assert_symbol_exists(
        self,
        sym_table: UniScopeNode,
        symbol_name: str,
        symbol_type: Optional[str] = None,
    ) -> Symbol:
        """Assert that a symbol exists in the symbol table."""
        symbol = look_down(sym_table, symbol_name)
        self.assertIsNotNone(
            symbol, f"Symbol '{symbol_name}' not found in symbol table"
        )
        if symbol_type:
            self.assertIn(
                symbol_type,
                str(symbol),
                f"Symbol '{symbol_name}' is not of type '{symbol_type}'",
            )
        return symbol

    def assert_symbol_decl_at(self, symbol: Symbol, line: int, col: int) -> None:
        """Assert that a symbol is declared at specific line and column."""
        decl_info = str(symbol)
        expected_decl = f"{line}:{col}"
        self.assertIn(
            expected_decl,
            decl_info,
            f"Symbol declaration not found at {expected_decl}. Got: {decl_info}",
        )

    def assert_symbol_defns_at(
        self, symbol: Symbol, expected_defns: list[tuple[int, int]]
    ) -> None:
        """Assert that a symbol has definitions at specific locations."""
        symbol_str = str(symbol)
        for line, col in expected_defns:
            expected_defn = f"{line}:{col}"
            self.assertIn(
                expected_defn,
                symbol_str,
                f"Symbol definition not found at {expected_defn}. Got: {symbol_str}",
            )

    def assert_symbol_uses_at(
        self, symbol: Symbol, expected_uses: list[tuple[int, int]]
    ) -> None:
        """Assert that a symbol has uses at specific locations."""
        symbol_uses_str = str(symbol.uses)
        for line, col in expected_uses:
            expected_use = f"{line}:{col}"
            self.assertIn(
                expected_use,
                symbol_uses_str,
                f"Symbol use not found at {expected_use}. Got: {symbol_uses_str}",
            )

    def assert_symbol_complete(
        self,
        sym_table: UniScopeNode,
        symbol_name: str,
        symbol_type: str,
        decl: tuple[int, int],
        defns: Optional[list[tuple[int, int]]] = None,
        uses: Optional[list[tuple[int, int]]] = None,
    ) -> None:
        """Assert complete symbol information (declaration, definitions, uses)."""
        symbol = self.assert_symbol_exists(sym_table, symbol_name, symbol_type)
        self.assert_symbol_decl_at(symbol, decl[0], decl[1])

        if defns:
            self.assert_symbol_defns_at(symbol, defns)

        if uses:
            self.assert_symbol_uses_at(symbol, uses)

    def assert_sub_table_exists(
        self, sym_table: UniScopeNode, table_name: str, tab_type: str
    ) -> None:
        """Assert that a sub-table exists in the symbol table."""
        sub_tables = sym_table.kid_scope
        table_names = [table.scope_name for table in sub_tables]
        type_names = [table.get_type() for table in sub_tables]
        matching_tables = [name for name in table_names if table_name in name]
        matching_types = [
            type_name for type_name in type_names if tab_type in str(type_name)
        ]
        self.assertTrue(
            len(matching_tables) > 0,
            f"Sub-table '{table_name}' not found. Available: {table_names}",
        )
        self.assertTrue(
            len(matching_types) > 0,
            f"Sub-table type '{tab_type}' not found in {table_names} of types {type_names}",
        )
        return sub_tables[table_names.index(matching_tables[0])]


def look_down(tab: UniScopeNode, name: str, deep: bool = True) -> Optional[Symbol]:
    """Lookup a variable in the symbol table."""
    if name in tab.names_in_scope:
        if not tab.names_in_scope[name].imported:
            return tab.names_in_scope[name]
        else:
            sym = tab.names_in_scope[name]
            return sym
    for i in tab.inherited_scope:
        found = i.lookup(name, deep=False)
        if found:
            return found
    if deep and tab.kid_scope:
        for kid in tab.kid_scope:
            found = kid.lookup(name, deep=True)
            if found:
                return found
    return None
