"""Check embedded-NUL string identity in native dictionaries and tuple sets."""
import ctypes;
import from tests.support { compile_native, get_func }
test "native container string keys include content after NUL" {
    (engine, _) = compile_native("string_nul_keys.jac");
    result = get_func(engine, "string_nul_keys", ctypes.c_int64)();
    assert result == 0 , f"string key check {result}";
}
