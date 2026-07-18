"""P1c phase-exit: arrays.c → list[T] with subscripting."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "c2jac", "fixtures");

def _transpile(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        src = f.read();
    }
    (jac_str, tags) = transpile_c_str(src, name);
    return jac_str;
}

test "arrays.c transpiles without error" {
    jac_str = _transpile("arrays.c");
    assert jac_str != "";
}

test "arrays.c contains list annotation" {
    jac_str = _transpile("arrays.c");
    assert "list" in jac_str , f"Expected 'list' type annotation in:\n{jac_str}";
}

test "arrays.c contains subscript access" {
    jac_str = _transpile("arrays.c");
    # Should contain subscript access like arr[0].
    assert "[" in jac_str , "Expected subscript '[]' in output";
}

test "arrays.c contains sum_array function" {
    jac_str = _transpile("arrays.c");
    assert "sum_array" in jac_str , "Expected 'sum_array' function";
}
