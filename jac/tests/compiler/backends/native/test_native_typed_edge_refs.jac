"""Native graph expressions expose objects, not the kernel's integer handles."""
import ctypes;
import from tests.support { compile_native, get_func }

test "typed edge comprehensions can filter imported and local node classes" {
    (engine, _) = compile_native("typed_edge_ref_main.jac");
    result = get_func(engine, "comprehension", ctypes.c_int64);
    assert result() == 2;
}

test "typed edge iteration preserves node identity and field access" {
    (engine, _) = compile_native("typed_edge_ref_main.jac");
    result = get_func(engine, "iteration", ctypes.c_int64);
    assert result() == 33;
}
