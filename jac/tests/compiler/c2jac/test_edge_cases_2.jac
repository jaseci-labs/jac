"""More edge cases for C-to-Jac transpiler."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "edge_cases_2.c";

test "edge_cases_2.c transpiles variadic function" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "def variadic_sum" in jac_str , jac_str;
    assert "*args" in jac_str , "Variadic should be lowered to *args";
}

test "edge_cases_2.c handles nested structs with pointers" {
    jac_str = _transpile(_FIXTURE);
    assert "class Inner" in jac_str , jac_str;
    assert "class Outer" in jac_str , jac_str;
}

test "edge_cases_2.c handles function pointer as parameter" {
    jac_str = _transpile(_FIXTURE);
    assert "def apply_func" in jac_str , jac_str;
}

test "edge_cases_2.c handles complex conditional expressions" {
    jac_str = _transpile(_FIXTURE);
    assert "def complex_conditional" in jac_str , jac_str;
}

test "edge_cases_2.c handles nested loops with break/continue" {
    jac_str = _transpile(_FIXTURE);
    assert "def nested_loops" in jac_str , jac_str;
}

test "edge_cases_2.c handles complex array initialization" {
    jac_str = _transpile(_FIXTURE);
    assert "def array_init" in jac_str , jac_str;
}

test "edge_cases_2.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "edge_cases_2.c");
    assert errs == [] , f"recompile errors: {errs}";
}
