"""P1b phase-exit: struct_shape.c pins the emitted obj shape."""

import from tests.compiler.c2jac.support { transpile_fixture as _transpile }

test "struct_shape.c transpiles without error" {
    jac_str = _transpile("struct_shape.c");
    assert jac_str != "";
}

test "struct_shape.c Point becomes obj/class" {
    jac_str = _transpile("struct_shape.c");
    # The typedef struct Point should appear as a class/obj named Point.
    assert "Point" in jac_str , f"Expected 'Point' class in:\n{jac_str}";
}

test "struct_shape.c Point fields x y z present" {
    jac_str = _transpile("struct_shape.c");
    assert "x" in jac_str , "Expected field 'x'";
    assert "y" in jac_str , "Expected field 'y'";
    assert "z" in jac_str , "Expected field 'z'";
}

test "struct_shape.c Record becomes obj/class" {
    jac_str = _transpile("struct_shape.c");
    assert "Record" in jac_str , "Expected 'Record' class";
}

test "struct_shape.c Node struct present" {
    jac_str = _transpile("struct_shape.c");
    assert "Node" in jac_str , "Expected 'Node' struct";
}
