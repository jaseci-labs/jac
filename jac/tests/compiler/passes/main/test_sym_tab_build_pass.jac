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
