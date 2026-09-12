"""Dictionary unpacking must merge entries instead of dropping spread operands."""
import ctypes;
import from tests.support { compile_native, get_func }

test "native dictionary unpack preserves order overwrites and ownership" {
    (engine, _) = compile_native("dict_unpack.jac");
    result = get_func(engine, "dict_unpack_check", ctypes.c_int64)();
    assert result == 0 , f"dictionary unpack check {result}";
}
