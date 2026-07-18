"""P2 phase-exit: pointer idiom fixture validates free()-elision,
malloc(sizeof(T))→T() lowering, and T* params typed as T."""

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

test "pointers.c transpiles without error" {
    jac_str = _transpile("pointers.c");
    assert jac_str != "";
}

test "pointers.c struct pointer params annotated as struct type" {
    jac_str = _transpile("pointers.c");
    assert ": Point" in jac_str , f"Expected ': Point' annotation, got:\n{jac_str}";
}

test "pointers.c free() call is elided" {
    jac_str = _transpile("pointers.c");
    assert "free" not in jac_str , f"Expected free() to be removed, got:\n{jac_str}";
}

test "pointers.c malloc(sizeof(Point)) lowered to Point() constructor" {
    jac_str = _transpile("pointers.c");
    assert "Point()" in jac_str , f"Expected Point() constructor, got:\n{jac_str}";
}

test "pointers.c struct field access p->x becomes p.x" {
    jac_str = _transpile("pointers.c");
    assert ".x" in jac_str , f"Expected .x field access, got:\n{jac_str}";
}
