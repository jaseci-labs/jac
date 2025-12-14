"""Symbol table testing helpers for Jaseci."""

import from jaclang.pycore.unitree { Symbol, UniScopeNode }

"""Lookup a variable in the symbol table."""
def look_down(tab: UniScopeNode, name: str, deep: bool = True) -> Symbol | None {
    if name in tab.names_in_scope {
        if not tab.names_in_scope[name].imported {
            return tab.names_in_scope[name];
        } else {
            sym = tab.names_in_scope[name];
            return sym;
        }
    }
    for i in tab.inherited_scope {
        found = i.base_symbol_table.lookup(name, deep=False);
        if found {
            return found;
        }
    }
    if deep and tab.kid_scope {
        for kid in tab.kid_scope {
            found = kid.lookup(name, deep=True);
            if found {
                return found;
            }
        }
    }
    return None;
}

"""Assert that a symbol exists in the symbol table."""
def assert_symbol_exists(
    sym_table: UniScopeNode, symbol_name: str, symbol_type: str | None = None
) -> Symbol {
    symbol = look_down(sym_table, symbol_name);
    assert symbol is not None , f"Symbol '{symbol_name}' not found in symbol table";
    if symbol_type {
        assert symbol_type in str(symbol) , (
            f"Symbol '{symbol_name}' is not of type '{symbol_type}'"
        );
    }
    return symbol;
}

"""Assert that a symbol is declared at specific line and column."""
def assert_symbol_decl_at(symbol: Symbol, line: int, col: int) -> None {
    decl_info = str(symbol);
    expected_decl = f"{line}:{col}";
    assert expected_decl in decl_info , (
        f"Symbol declaration not found at {expected_decl}. Got: {decl_info}"
    );
}

"""Assert that a symbol has definitions at specific locations."""
def assert_symbol_defns_at(
    symbol: Symbol, expected_defns: list[tuple[int, int]]
) -> None {
    symbol_str = str(symbol);
    for (line, col) in expected_defns {
        expected_defn = f"{line}:{col}";
        assert expected_defn in symbol_str , (
            f"Symbol definition not found at {expected_defn}. Got: {symbol_str}"
        );
    }
}

"""Assert that a symbol has uses at specific locations."""
def assert_symbol_uses_at(symbol: Symbol, expected_uses: list[tuple[int, int]]) -> None {
    symbol_uses_str = str(symbol.uses);
    for (line, col) in expected_uses {
        expected_use = f"{line}:{col}";
        assert expected_use in symbol_uses_str , (
            f"Symbol use not found at {expected_use}. Got: {symbol_uses_str}"
        );
    }
}

"""Assert complete symbol information (declaration, definitions, uses)."""
def assert_symbol_complete(
    sym_table: UniScopeNode,
    symbol_name: str,
    symbol_type: str,
    decl: tuple[int, int],
    defns: list[tuple[int, int]] | None = None,
    uses: list[tuple[int, int]] | None = None
) -> None {
    symbol = assert_symbol_exists(sym_table, symbol_name, symbol_type);
    assert_symbol_decl_at(symbol, decl[0], decl[1]);

    if defns {
        assert_symbol_defns_at(symbol, defns);
    }

    if uses {
        assert_symbol_uses_at(symbol, uses);
    }
}

"""Assert that a sub-table exists in the symbol table."""
def assert_sub_table_exists(
    sym_table: UniScopeNode, table_name: str, tab_type: str
) -> UniScopeNode {
    sub_tables = sym_table.kid_scope;
    table_names = [table.scope_name for table in sub_tables];
    type_names = [table.get_type() for table in sub_tables];
    matching_tables = [
        name
        for name in table_names
        if table_name in name
    ];
    matching_types = [
        type_name
        for type_name in type_names
        if tab_type in str(type_name)
    ];
    assert len(matching_tables) > 0 , (
        f"Sub-table '{table_name}' not found. Available: {table_names}"
    );
    assert len(matching_types) > 0 , (
        f"Sub-table type '{tab_type}' not found in {table_names} of types {type_names}"
    );
    return sub_tables[table_names.index(matching_tables[0])];
}
