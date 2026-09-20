"""Return coercions transfer the existing temporary's ownership exactly once."""
import ctypes;
import from tests.support { compile_native, get_func }

test "return coercions preserve strings and optional and tuple values" {
    (engine, _) = compile_native("return_coercion_ownership.jac");
    for name in ["check", "box_preserves_owner"] {
        check = get_func(engine, name, ctypes.c_bool);
        for _ in range(100) {
            assert check() , name;
        }
    }
}
