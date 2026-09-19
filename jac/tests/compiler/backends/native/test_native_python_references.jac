"""Retained Python values keep identity and release references across native calls."""
import ctypes;
import functools;
import sys;
import from tests.support { compile_native, get_python_func }
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }

@functools.cache
def engine -> ExecutionEngine {
    (native, module) = compile_native("python_references.jac");
    assert module.gen.llvm_ir is not None;
    return native;
}

def object_call(name: str, arity: int) -> any {
    return get_python_func(
        engine(), name, ctypes.c_void_p, *([ctypes.py_object] * arity)
    );
}

def take(value: int) -> any {
    assert value != 0 , "native result was NULL without an exception";
    result = ctypes.cast(value, ctypes.py_object).value;
    release = ctypes.pythonapi.Py_DecRef;
    release.argtypes = [ctypes.c_void_p];
    release.restype = None;
    release(value);
    return result;
}

test "owned references transfer once and aliases clear before release" {
    identity = object_call("retained_identity", 1);
    release = get_python_func(engine(), "release_local", None, ctypes.py_object);
    clear_alias = get_python_func(engine(), "release_alias", None, ctypes.py_object);
    value = object();
    before = sys.getrefcount(value);
    for _ in range(1000) {
        release(value);
        clear_alias(value);
        assert take(identity(value)) is value;
    }
    assert sys.getrefcount(value) == before;
}

test "generic native calls retain object identity and mutable aliases" {
    call = object_call("import_call", 4);
    method = object_call("method_call", 4);
    original = {"text": "a\x00中😀", "integer": 1 << 200};
    encoded = take(call("json", "dumps", (original, ), {"sort_keys": True}));
    assert take(call("json", "loads", (encoded, ), {})) == original;
    value: list[int] = [];
    container = {"value": value};
    alias = take(method(container, "get", ("value", ), {}));
    assert alias is value;
    take(method(alias, "append", (42, ), {}));
    assert value == [42];
}

test "native exception unwinding releases nested frames and preserves the error" {
    call = object_call("call_with_witness", 4);
    sentinel = ValueError("original error");
    witness = object();
    def fail -> None {
        raise sentinel;
    }
    before_witness = sys.getrefcount(witness);
    before_error = sys.getrefcount(sentinel);
    for _ in range(1000) {
        try {
            call(fail, (), {}, witness);
        } except ValueError as error {
            assert error is sentinel;
        } else {
            raise AssertionError("native entry lost the Python exception");
        }
    }
    assert sys.getrefcount(witness) == before_witness;
    assert sys.getrefcount(sentinel) == before_error;
}

test "null references and runtime import errors remain Python exceptions" {
    call = object_call("import_call", 4);
    try {
        call("__jac_missing_runtime_module__", "method", (), {});
    } except ModuleNotFoundError {} else {
        raise AssertionError("native import lost ModuleNotFoundError");
    }
    try {
        object_call("borrow_null", 0)();
    } except SystemError {} else {
        raise AssertionError("native borrow accepted a NULL object");
    }
}
