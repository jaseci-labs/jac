"""Test SymTable Link Pass."""

import os

from jaclang.pycore.program import JacProgram


def test_no_dupl_symbols() -> None:
    """Basic test for pass."""
    file_path = os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "symtab_link_tests",
        "no_dupls.jac",
    )
    mod = JacProgram().build(file_path)
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
        "symtab_link_tests",
        "main.jac",
    )
    prog = JacProgram()
    prog.compile(file_path)
    assert prog.errors_had == []
    assert prog.warnings_had == []
