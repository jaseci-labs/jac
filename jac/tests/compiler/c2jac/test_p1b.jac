"""P1b phase-exit: struct_shape.c pins the emitted obj shape."""

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
