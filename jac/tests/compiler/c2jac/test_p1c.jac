"""P1c phase-exit: arrays.c → list[T] with subscripting."""

import from tests.compiler.c2jac.support { transpile_fixture as _transpile }

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

test "scalar array uses immutable-element repeat (no aliasing risk)" {
    # `int arr[5];` → `[0] * 5` is fine — ints can't alias.
    jac_str = _transpile("arrays.c");
    assert "* 5" in jac_str , f"Expected scalar `* 5` repeat in:\n{jac_str}";
}

test "uninitialized object array emits distinct elements, not [T()] * n" {
    # `struct S a[2];` must become `[S() for _ in range(2)]`, NOT `[S()] * 2`
    # — the latter aliases one instance into every slot, so `a[0].x = 1` and
    # `a[1].x = 2` would clobber the same object.
    jac_str = _transpile("struct_array.c");
    assert "for _ in range(2)" in jac_str , f"Expected per-element comprehension for struct array in:\n{jac_str}";
    assert "] * 2" not in jac_str , f"Aliasing `[S()] * 2` must not appear in:\n{jac_str}";
}
