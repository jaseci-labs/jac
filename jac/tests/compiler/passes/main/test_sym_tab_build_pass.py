"""Test SymTable Build Pass."""

import os

from jaclang.pycore.program import JacProgram


def test_no_dupl_symbols() -> None:
    """Basic test for pass."""
    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_build_tests",
        "no_dupls.jac",
    )
    mod = JacProgram().compile(file_path)
    assert len(mod.sym_tab.names_in_scope.values()) == 3

    for i in ["[Symbol(a,", "Symbol(Man,", "Symbol(p,"]:
        assert i in str(mod.sym_tab.names_in_scope.values())
    # TODO: def use is called on single file so this breaks
    # Def Use pass will go away with full type checking
    # assert len(mod.sym_tab.names_in_scope["a"].uses) == 4
    # assert len(
    #     list(
    #         mod.sym_tab.kid_scope[0]
    #         .kid_scope[0]
    #         .kid_scope[0]
    #         .kid_scope[0]
    #         .inherited_scope[0]
    #         .base_symbol_table.names_in_scope.values()
    #     )[0].uses,
    # ) == 3


def test_package() -> None:
    """Test package."""
    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_build_tests",
        "main.jac",
    )
    prog = JacProgram()
    prog.compile(file_path)
    assert prog.errors_had == []
    assert prog.warnings_had == []


def test_inner_compr_iteration_variable() -> None:
    """Test that iteration variables in comprehensions are registered in symbol table."""
    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_build_tests",
        "list_comprehension.jac",
    )
    mod = JacProgram().compile(file_path)

    compr_names = mod.sym_tab.kid_scope[0].names_in_scope

    # The iteration variable 'x' should be in the InnerCompr's symbol table
    assert "x" in compr_names, (
        "Iteration variable 'x' should be registered in InnerCompr symbol table"
    )


def test_expr_as_item_alias_variable() -> None:
    """Test that alias variables in 'as' clauses are registered in symbol table."""

    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_build_tests",
        "with_as_clause.jac",
    )
    mod = JacProgram().compile(file_path)

    with_names = mod.sym_tab.kid_scope[0].names_in_scope

    # The alias variable 'f' should be in the WithStmt's symbol table
    assert "f" in with_names, (
        "Alias variable 'f' should be registered in WithStmt symbol table"
    )

    assert str(with_names["f"].sym_type) == "variable"


def test_in_for_stmt_iteration_variables() -> None:
    """Test that iteration variables in for loops are registered in symbol table."""

    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_build_tests",
        "for_loop_unpacking.jac",
    )
    mod = JacProgram().compile(file_path)

    test_cases = [
        (0, ["x"]),
        (1, ["a", "b"]),
        (2, ["a", "b", "c"]),
        (3, ["name", "x", "y"]),
        (4, ["first", "middle", "last"]),
        (5, ["a", "b", "c", "d"]),
    ]

    for scope_idx, expected_vars in test_cases:
        for_loop_scope = mod.sym_tab.kid_scope[scope_idx]
        for var_name in expected_vars:
            assert var_name in for_loop_scope.names_in_scope
