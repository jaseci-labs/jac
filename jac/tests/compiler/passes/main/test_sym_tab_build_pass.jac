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
        (1, {"a","b","rest"}, uni.ListCompr),
        (2, {"a","b","c","d"}, uni.ListCompr),
        (3, {"a","b"}, uni.SetCompr),
        (4, {"k","v"}, uni.DictCompr),
        (5, {"a","b"}, uni.GenCompr),
        (6, {"row","name","val"}, uni.ListCompr)
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

"""Test that sys.version_info conditionals are evaluated during symbol table building.

Pyright reference: staticExpressions.ts - evaluateStaticBoolLikeExpression
This ensures symbols inside version conditionals like 'if sys.version_info >= (3, 11): Self: _SpecialForm'
are properly registered when the condition is true for the current Python version.
"""
test "version conditional evaluation" {
    import sys;
    import ast as py_ast;
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }

    # Test Python code with version conditionals
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

    # Check which symbols are registered
    # Use incl_inner_scope=True to search child scopes (if statements don't create namespaces in Python)
    self_sym = mod.lookup("Self", deep=True, incl_inner_scope=True);
    never_sym = mod.lookup("Never", deep=True, incl_inner_scope=True);
    future_sym = mod.lookup("Future", deep=True, incl_inner_scope=True);
    always_sym = mod.lookup("Always", deep=True, incl_inner_scope=True);

    print(f"\nPython version: {sys.version_info.major}.{sys.version_info.minor}");
    print(f"Self symbol: {self_sym}");
    print(f"Never symbol: {never_sym}");
    print(f"Future symbol: {future_sym}");
    print(f"Always symbol: {always_sym}");

    # Always should always be found
    assert always_sym is not None , "Always should always be found";

    # On Python 3.11+, Self and Never should be found
    if sys.version_info >= (3, 11) {
        assert self_sym is not None , "Self should be found on Python 3.11+";
        assert never_sym is not None , "Never should be found on Python 3.11+";
    }

    # Future should NOT be found (requires Python 3.15+)
    assert future_sym is None , "Future should NOT be found on Python < 3.15";
}
