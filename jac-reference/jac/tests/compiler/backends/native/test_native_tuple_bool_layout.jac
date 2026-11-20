"""Check boolean tuple fields after boxing in typed containers."""
import ctypes;
import from tests.support { compile_native, get_func }
test "native tuples preserve declared boolean field layout" {
    (engine, _) = compile_native("tuple_bool_layout.jac");
    result = get_func(engine, "tuple_bool_check", ctypes.c_int64)();
    assert result == 0 , f"tuple boolean check {result}";
}
