"""Tuple arity and semantic coercions survive generic pointer storage."""
import ctypes;
import from tests.support { compile_native, get_func }

test "dictionary tuple storage preserves arity and element coercions" {
    (engine, fx) = compile_native("dict_tuple_coercions.jac");
    assert not fx.iface().demoted , fx.iface().demoted;
    assert get_func(engine, "singleton", ctypes.c_int64)() == 44;
    assert get_func(engine, "widened_numeric", ctypes.c_double)() == 7.0;
    assert get_func(engine, "optional_elements", ctypes.c_int64)() == 10;
}
