"""Python-backed globals retain identity and initialize in source order."""
import ctypes;
import math;
import from tests.support { compile_native, get_func }


test "Python global initialization interleaves imports and retains object aliases" {
    original = math.sqrt;
    def first(value: float) -> int {
        setattr(math, "sqrt", lambda (value: float) { 22; });
        return 11;
    }
    setattr(math, "sqrt", first);
    try {
        (engine, module) = compile_native("python_global_values.jac", required=True);
        assert engine.requires_python;
        assert get_func(engine, "ordered_values", ctypes.c_int64)() == 1122;
        native_value = get_func(engine, "native_scalar", ctypes.c_double)();
        assert native_value == 22.0, str(native_value);
        assert get_func(engine, "mutate", ctypes.c_int64)() == 3;
        assert get_func(engine, "replace", ctypes.c_int64)() == 13;
        assert get_func(engine, "context_default", ctypes.c_int64)() == 7;
        ir = str(module.gen.llvm_ir);
        assert '@"VALUE" = global' not in ir;
        assert '@"CONTEXT" = global' not in ir;
    } finally {
        math.sqrt = original;
    }
}


test "failed Python global initialization releases partial values and retries" {
    import sys;
    (engine, _) = compile_native("python_global_values.jac", required=True);
    sentinel = object();
    baseline = sys.getrefcount(sentinel);
    original = math.sqrt;
    calls: list[float] = [];
    def fail_later(value: float) -> any {
        calls.append(value);
        if len(calls) == 1 {
            return sentinel;
        }
        raise RuntimeError("global initialization failed");
    }
    setattr(math, "sqrt", fail_later);
    try {
        try {
            get_func(engine, "context_default", ctypes.c_int64)();
            assert False , "partial initialization returned successfully";
        } except RuntimeError as error {
            assert str(error) == "global initialization failed";
        }
        assert calls == [4.0, 9.0];
        assert sys.getrefcount(sentinel) == baseline;
        math.sqrt = original;
        assert get_func(engine, "ordered_values", ctypes.c_int64)() == 203;
        assert get_func(engine, "context_default", ctypes.c_int64)() == 7;
    } finally {
        math.sqrt = original;
    }
}


test "Python global objects are isolated between interpreter instances" {
    import _interpreters;
    (engine, _) = compile_native("python_global_values.jac", required=True);
    mutate = get_func(engine, "mutate", ctypes.c_int64);
    assert mutate() == 3;
    address = engine.get_function_address("mutate");
    for _ in range(2) {
        interpreter = _interpreters.create("legacy");
        try {
            failure = _interpreters.run_string(
                interpreter,
                "import ctypes\n"
                f"mutate = ctypes.PYFUNCTYPE(ctypes.c_int64)({address})\n"
                "assert mutate() == 3\n"
                "assert mutate() == 4\n"
            );
            assert failure is None , str(failure);
        } finally {
            _interpreters.destroy(interpreter);
        }
    }
    assert mutate() == 4;
}
