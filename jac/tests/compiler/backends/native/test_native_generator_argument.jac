"""Check element inference for generators passed directly to builtins."""
import ctypes;
import from tests.support { compile_native, get_func }
test "native generator arguments preserve boolean element storage" {
    (engine, _) = compile_native("generator_bool_argument.jac");
    result = get_func(engine, "generator_bool_check", ctypes.c_int64)();
    assert result == 0 , f"generator argument check {result}";
}
