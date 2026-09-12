"""Optional parameter promotion owns the value released by assignment."""
import ctypes;
import from tests.support { compile_native, get_func }
test "native optional parameter rebinding preserves caller ownership" {
    (engine, _) = compile_native("optional_parameter_rebind.jac");
    result = get_func(engine, "optional_parameter_check", ctypes.c_int64)();
    assert result == 0 , f"optional parameter check {result}";
}
