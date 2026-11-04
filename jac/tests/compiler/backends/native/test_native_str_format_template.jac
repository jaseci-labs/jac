"""str.format with a literal template lowers natively: automatic, numbered and
keyword fields, conversions, constant specs and escaped braces."""
import ctypes;
import from tests.support { compile_native, get_func }

test "a literal str.format template formats like Python" {
    (eng, _) = compile_native("str_format_template.jac");
    got = get_func(eng, "chk_format", ctypes.c_int64, ctypes.c_int64)(7);
    assert got == 63 , got;
}
