"""Exact archetype identity survives native module boundaries."""

import ctypes;
import from tests.support { compile_native, get_func }

test "type identity recognizes imported instances and rejects subclasses" {
    (engine, _) = compile_native("type_identity.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 0;
}
