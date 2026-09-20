"""Native calls use the interpreter's stdlib implementations and module objects."""
import ctypes;
import math;
import from unittest.mock { patch }
import from tests.support { compile_native, get_func }

test "native stdlib calls preserve complete APIs and Python exceptions" {
    (engine, module) = compile_native("python_stdlib_delegation.jac", required=True);
    assert engine.requires_python;
    assert get_func(engine, "stdlib_surface", ctypes.c_bool)();
    sqrt = get_func(engine, "patched_sqrt", ctypes.c_double);
    assert sqrt() == 2.0;
    with patch.object(math, "sqrt", return_value=91.0) {
        assert sqrt() == 91.0;
    }
    assert sqrt() == 2.0;
    assert module.gen.interop_manifest.native_transitive_sources;
}
