"""Boxed reference returns survive release of the caller's temporary argument."""

import ctypes;
import from tests.support { compile_native }

test "iteration keeps a boxed getter result alive" {
    (engine, _) = compile_native("boxed_return_lifetime.jac");
    probe = ctypes.CFUNCTYPE(ctypes.c_int64)(engine.get_function_address("probe"));
    for i in range(20) {
        assert probe() == 10;
    }
}
