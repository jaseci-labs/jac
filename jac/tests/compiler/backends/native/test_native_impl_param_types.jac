"""A parameter whose impl annotation differs from its declaration lowers.

The function receives the declared type and its body works on the impl's
type; the parameter is converted once, on entry.
"""
import ctypes;
import from tests.support { compile_native, get_func }

test "an impl parameter wider than its declaration is converted on entry" {
    (eng, _) = compile_native("impl_param_annotation.jac");
    assert get_func(eng, "chk", ctypes.c_int64)() == 69;
}
