"""Check native optional object storage in list displays."""
import ctypes;
import from tests.support { compile_native, get_func }
test "native list displays preserve optional object elements" {
    (engine, _) = compile_native("optional_list_display.jac");
    result = get_func(engine, "optional_list_check", ctypes.c_int64)();
    assert result == 0 , f"optional list display check {result}";
}
