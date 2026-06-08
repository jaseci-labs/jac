"""Symbol table build pass tests – migrated from test_sym_tab_build_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "symtab_build_tests"
     );

test "no dupl symbols" {
    file_path = os.path.join(FIXTURES, "no_dupls.jac");
    mod = JacProgram().compile(file_path);
    assert len(mod.sym_tab.names_in_scope.values()) == 3;
    for i in ["[Symbol(a,", "Symbol(Man,", "Symbol(p,"] {
        assert i in str(mod.sym_tab.names_in_scope.values());
    }
}

test "package" {
    file_path = os.path.join(FIXTURES, "main.jac");
    prog = JacProgram();
    prog.compile(file_path);
    assert prog.errors_had == [];
    assert prog.warnings_had == [];
}

test "expr as item alias variable" {
    file_path = os.path.join(FIXTURES, "with_as_clause.jac");
    mod = JacProgram().compile(file_path);
    with_names = mod.sym_tab.kid_scope[0].names_in_scope;
    assert "f" in with_names , "Alias variable 'f' should be registered in WithStmt symbol table";
    assert str(with_names["f"].sym_type) == "variable";
}

test "in for stmt iteration variables" {
    file_path = os.path.join(FIXTURES, "for_loop_unpacking.jac");
    mod = JacProgram().compile(file_path);
    test_cases = [
        (0, ["x"]),
        (1, ["a", "b"]),
        (2, ["a", "b", "c"]),
        (3, ["name", "x", "y"]),
        (4, ["first", "middle", "last"]),
        (5, ["a", "b", "c", "d"])
    ];
    for (scope_idx, expected_vars) in test_cases {
        for_loop_scope = mod.sym_tab.kid_scope[scope_idx];
        for var_name in expected_vars {
            assert var_name in for_loop_scope.names_in_scope;
        }
    }
}

test "compr unpacking variables" {
    file_path = os.path.join(FIXTURES, "comprehension_patterns.jac");
    mod = JacProgram().compile(file_path);
    test_cases = [
        (0, {"x"}, uni.ListCompr),
        (1, {"a", "b", "rest"}, uni.ListCompr),
        (2, {"a", "b", "c", "d"}, uni.ListCompr),
        (3, {"a", "b"}, uni.SetCompr),
        (4, {"k", "v"}, uni.DictCompr),
        (5, {"a", "b"}, uni.GenCompr),
        (6, {"row", "name", "val"}, uni.ListCompr)
    ];
    for (scope_idx, expected_vars, expected_type) in test_cases {
        scope = mod.sym_tab.kid_scope[scope_idx];
        actual_vars = set(scope.names_in_scope.keys());
        assert actual_vars == expected_vars , f"Scope {scope_idx}: expected {expected_vars}, got {actual_vars}";
        assert isinstance(scope, expected_type) , f"Scope {scope_idx}: expected type {expected_type}, got {type(
            scope
        )}";
    }
}

test "except variable registration" {
    file_path = os.path.join(FIXTURES, "symtab_features.jac");
    mod = JacProgram().compile(file_path);
    try_stmt = mod.sym_tab.kid_scope[0];
    except_clause = try_stmt.kid_scope[0];
    assert "e" in except_clause.names_in_scope , "Exception variable 'e' should be registered in except block symbol table";
}

test "assignment patterns" {
    file_path = os.path.join(FIXTURES, "assignment_patterns.jac");
    mod = JacProgram().compile(file_path);
    scope_vars = mod.sym_tab.names_in_scope;
    for var in ["a2", "b2", "c2", "f2", "g2", "d"] {
        assert var in scope_vars;
    }
}

"""Test that InnerCompr scopes are properly linked and can lookup outer symbols."""
test "inner compr scope linking" {
    file_path = os.path.join(FIXTURES, "inner_compr_scope.jac");
    mod = JacProgram().compile(file_path);

    gen_compr = mod.sym_tab.kid_scope[0];
    inner_compr = gen_compr.kid_scope[0];

    assert "p" in gen_compr.names_in_scope;
    assert inner_compr.parent_scope is not None;
    assert inner_compr.lookup("pool", True) is not None;
}

"""The symbol table records every guard branch, live or dead (version-agnostic)."""
test "version conditional symbols are all recorded in the symbol table" {
    import ast as py_ast;
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }

    code = """
import sys

if sys.version_info >= (3, 11):
    Self = "special_form_311"
    Never = "never_311"

if sys.version_info >= (3, 15):
    Future = "future_315"

Always = "always_available"
""";

    prog = JacProgram();
    source = uni.Source(code, "test_version.py");
    py_ast_node = py_ast.parse(code);

    mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_ast_node, orig_src=source), prog=prog
    ).ir_out;

    SymTabBuildPass(ir_in=mod, prog=prog);

    # Every guarded declaration is in the (complete) symbol table, regardless
    # of whether its guard is statically live — including the >= 3.15 branch.
    assert mod.lookup("Always", deep=True, incl_inner_scope=True) is not None;
    assert mod.lookup("Self", deep=True, incl_inner_scope=True) is not None;
    assert mod.lookup("Never", deep=True, incl_inner_scope=True) is not None;
    assert mod.lookup("Future", deep=True, incl_inner_scope=True) is not None;
}

"""collect_member_syms resolves the live guard branch and skips the dead one."""
test "version-live branch resolves, dead branch does not" {
    import sys;
    import ast as py_ast;
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
    import from jaclang.compiler.type_system.type_utils { collect_member_syms }

    # Annotated decls (as typeshed writes guarded symbols) stay in the guard
    # scope instead of hoisting to module level.
    code = """
import sys

MINYEAR: int

if sys.version_info >= (3, 11):
    UTC: str

if sys.version_info >= (3, 15):
    FUTURE_CONST: str
""";

    prog = JacProgram();
    source = uni.Source(code, "test_stub_module.py");
    py_ast_node = py_ast.parse(code);
    mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_ast_node, orig_src=source), prog=prog
    ).ir_out;
    SymTabBuildPass(ir_in=mod, prog=prog);

    assert collect_member_syms(mod, "MINYEAR") , "unguarded symbol should resolve";
    if sys.version_info >= (3, 11) {
        assert collect_member_syms(mod, "UTC") , "live guard should resolve";
    }
    # >= 3.15 is dead: in the symbol table, but the collector must not resolve it.
    assert not collect_member_syms(mod, "FUTURE_CONST") , "dead guard must not resolve";
}

"""Version-guarded class members resolve to the live branch (typeshed
`zip.__new__`-style per-version definitions)."""
test "version-guarded class members resolve to the live branch" {
    import sys;
    import ast as py_ast;
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
    import from jaclang.compiler.type_system.type_utils { collect_member_syms }

    code = """
import sys

class C:
    if sys.version_info >= (3, 11):
        def live_method(self) -> int: ...
    else:
        def dead_method(self) -> int: ...

    if sys.version_info >= (3, 15):
        def future_method(self) -> int: ...
""";

    prog = JacProgram();
    source = uni.Source(code, "test_guarded_class.py");
    py_ast_node = py_ast.parse(code);
    mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_ast_node, orig_src=source), prog=prog
    ).ir_out;
    SymTabBuildPass(ir_in=mod, prog=prog);

    cls_sym = mod.lookup("C", deep=False);
    assert cls_sym is not None , "class C should resolve";
    cls_scope = cls_sym.decl.name_of.sym_tab;

    if sys.version_info >= (3, 11) {
        assert collect_member_syms(cls_scope, "live_method") , "live `if` should resolve";
        assert not collect_member_syms(cls_scope, "dead_method") , "dead `else` must not resolve";
    }
    assert not collect_member_syms(cls_scope, "future_method") , "dead guard must not resolve";
}
