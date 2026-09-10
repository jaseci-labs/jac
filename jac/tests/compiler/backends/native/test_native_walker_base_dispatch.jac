"""Inherited methods spawn the concrete walker across module boundaries."""

import ctypes;
import from tests.support { compile_native, get_func }

test "base method dispatches derived walker" {
    (engine, _) = compile_native("walker_base_dispatch.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 121;
    overridden = get_func(engine, "override_probe", ctypes.c_int64);
    assert overridden() == 91;
}
