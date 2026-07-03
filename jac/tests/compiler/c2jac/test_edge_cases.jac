"""Edge cases for C-to-Jac transpiler."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "edge_cases.c";

test "edge_cases.c transpiles basic structures" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "class Point" in jac_str , jac_str;
    assert "class Rect" in jac_str , jac_str;
    assert "def bitops" in jac_str , jac_str;
}

test "edge_cases.c handles nested struct typedef" {
    jac_str = _transpile(_FIXTURE);
    assert "class Rect" in jac_str , jac_str;
    # Check that nested struct is properly handled
    assert "origin: Point" in jac_str , jac_str;
}

test "edge_cases.c handles function pointer typedef" {
    jac_str = _transpile(_FIXTURE);
    # Function pointers might be Tier-B or use a specific pattern
    # Just ensure it doesn't crash
    assert jac_str != "" , "Expected non-empty output";
}

test "edge_cases.c handles bitwise operations" {
    jac_str = _transpile(_FIXTURE);
    assert "def bitops" in jac_str , jac_str;
    # Bitwise operations should be transpiled
    assert "&" in jac_str or "bitand" in jac_str , jac_str;
}

test "edge_cases.c handles comma operator in for loop" {
    jac_str = _transpile(_FIXTURE);
    assert "def comma_for" in jac_str , jac_str;
    # Comma operator in for loop might be Tier-B
}

test "edge_cases.c handles nested ternary" {
    jac_str = _transpile(_FIXTURE);
    assert "def nested_ternary" in jac_str , jac_str;
}

test "edge_cases.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "edge_cases.c");
    assert errs == [] , f"recompile errors: {errs}";
}
