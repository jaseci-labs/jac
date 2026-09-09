"""Inherited methods spawn the concrete walker across module boundaries."""

import ctypes;
import from tests.support { compile_native }

test "base method dispatches derived walker" {
    (engine, _) = compile_native("walker_base_dispatch.jac");
    probe = ctypes.CFUNCTYPE(ctypes.c_int64)(engine.get_function_address("probe"));
    assert probe() == 121;
    overridden = ctypes.CFUNCTYPE(ctypes.c_int64)(
        engine.get_function_address("override_probe")
    );
    assert overridden() == 91;
}
