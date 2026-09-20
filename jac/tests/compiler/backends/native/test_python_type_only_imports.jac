"""Erased imports must not make native initialization depend on Python."""
import ctypes;
import from tests.support { compile_native, get_func }

test "type only Python imports do not initialize interpreter bindings" {
    (engine, _) = compile_native("python_type_only_imports.jac", required=True);
    assert not engine.requires_python;
    assert get_func(engine, "answer", ctypes.c_int64)() == 42;
    assert get_func(engine, "local_answer", ctypes.c_int64)() == 19;
}
