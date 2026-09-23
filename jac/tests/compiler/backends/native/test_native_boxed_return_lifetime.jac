"""Boxed reference returns survive release of the caller's temporary argument."""

import ctypes;
import from tests.support { compile_native, get_func }

test "iteration keeps a boxed getter result alive" {
    (engine, _) = compile_native("boxed_return_lifetime.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    for i in range(20) {
        assert probe() == 10;
    }
}
