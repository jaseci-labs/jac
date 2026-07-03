"""Advanced edge cases for C-to-Jac transpiler."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "edge_cases_3.c";

test "edge_cases_3.c transpiles bit fields" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "class BitFields" in jac_str , jac_str;
    # Bit fields might be Tier-B or handled differently
}

test "edge_cases_3.c handles nested arrays" {
    jac_str = _transpile(_FIXTURE);
    assert "def nested_array" in jac_str , jac_str;
}

test "edge_cases_3.c handles pointer arithmetic with arrays" {
    jac_str = _transpile(_FIXTURE);
    assert "def pointer_array" in jac_str , jac_str;
}

test "edge_cases_3.c handles nested struct with array" {
    jac_str = _transpile(_FIXTURE);
    assert "class IntArray" in jac_str , jac_str;
    assert "class MultiArray" in jac_str , jac_str;
}

test "edge_cases_3.c handles complex return types" {
    jac_str = _transpile(_FIXTURE);
    assert "def make_point" in jac_str , jac_str;
    assert "-> Point" in jac_str , jac_str;
}

test "edge_cases_3.c handles complex conditional chains" {
    jac_str = _transpile(_FIXTURE);
    assert "def conditional_chain" in jac_str , jac_str;
    # Complex if-else chains should have multiple conditions
}

test "edge_cases_3.c handles nested loops with complex conditions" {
    jac_str = _transpile(_FIXTURE);
    assert "def nested_complex" in jac_str , jac_str;
}

test "edge_cases_3.c handles switch with multiple cases" {
    jac_str = _transpile(_FIXTURE);
    assert "def switch_multiple" in jac_str , jac_str;
}

test "edge_cases_3.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "edge_cases_3.c");
    assert errs == [] , f"recompile errors: {errs}";
}
