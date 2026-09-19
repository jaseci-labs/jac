"""Retained Python values keep identity and release references across native calls."""
import ctypes;
import functools;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.dist.native_product { write_native_product }
import from jaclang.runtime.interop_bridge { NativeLibrary, native_callable }

@functools.cache
def engine -> ExecutionEngine {
    (native, module) = compile_native("python_references.jac");
    assert module.gen.llvm_ir is not None;
    assert native.requires_python;
    return native;
}

def object_call(name: str, arity: int) -> any {
    return get_func(engine(), name, ctypes.c_void_p, *([ctypes.py_object] * arity));
}

def take(value: int) -> any {
    assert value != 0 , "native result was NULL without an exception";
    result = ctypes.cast(value, ctypes.py_object).value;
    release = ctypes.pythonapi["Py_DecRef"];
    release.argtypes = [ctypes.c_void_p];
    release.restype = None;
    release(value);
    return result;
}

test "owned references transfer once and aliases clear before release" {
    identity = object_call("retained_identity", 1);
    release = get_func(engine(), "release_local", None, ctypes.py_object);
    clear_alias = get_func(engine(), "release_alias", None, ctypes.py_object);
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

test "error results release nested frames and preserve the original exception" {
    call = object_call("call_with_witness", 4);
    sentinel = ValueError("original error");
    witness = object();
    before_witness = sys.getrefcount(witness);
    def fail {
        assert sys.getrefcount(witness) > before_witness;
        raise sentinel;
    }
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

test "the hosted shared-library loader keeps the interpreter lock" {
    program = JacProgram();
    module = program.compile(
        file_path=str(Path(NATIVE_FIXTURES) / "python_references.jac"),
        options=CompileOptions(
            aot_mode=True,
            force_codespace="native",
            force_target_program=True,
            native_required=True
        )
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    assert module is not None;
    with tempfile.TemporaryDirectory() as directory {
        try {
            write_native_product(
                module, Path(directory), Path("unhosted"), shared=False
            );
        } except ValueError as error {
            assert "hosted Python runtime" in str(error);
        } else {
            raise AssertionError("Python-dependent code became an unhosted executable");
        }
        product = write_native_product(
            module, Path(directory), Path("references"), emit_source=False
        );
        assert product["requires_python"];
        library = NativeLibrary(
            str(Path(directory) / product["output"]),
            requires_python=product["requires_python"]
        );
        check = library.handle().gil_held;
        check.argtypes = [];
        check.restype = ctypes.c_int32;
        assert check() == 1;
        failing = library.handle().borrow_null;
        failing.argtypes = [];
        failing.restype = ctypes.c_void_p;
        try {
            failing();
        } except SystemError {} else {
            raise AssertionError("hosted loader lost the Python exception");
        }
    }
}

test "native entry conventions follow the runtime requirement" {
    address = engine().get_function_address("gil_held");
    assert native_callable(address, True, ctypes.c_int32)() == 1;
    assert native_callable(address, False, ctypes.c_int32)() == 0;
}

test "LLVM lifecycle entries retain Python interpreter state" {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    module = llvm.parse_assembly(
        "@seen = global i32 -1\n"
            + "declare i32 @PyGILState_Check()\n"
            + "define void @check_gil() {\n"
            + "  %held = call i32 @PyGILState_Check()\n"
            + "  store i32 %held, ptr @seen\n"
            + "  ret void\n}\n"
            + "@llvm.global_ctors = appending global [1 x {i32, ptr, ptr}] "
            + "[{i32, ptr, ptr} {i32 65535, ptr @check_gil, ptr null}]\n"
            + "@llvm.global_dtors = appending global [1 x {i32, ptr, ptr}] "
            + "[{i32, ptr, ptr} {i32 65535, ptr @check_gil, ptr null}]\n"
    );
    machine = llvm.Target.from_default_triple().create_target_machine();
    native = llvm.create_mcjit_compiler(module, machine);
    try {
        assert native.requires_python;
        native.finalize_object();
        seen = ctypes.c_int32.from_address(native.get_global_value_address("seen"));
        native.run_static_constructors();
        assert seen.value == 1;
        seen.value = -1;
        native.run_static_destructors();
        assert seen.value == 1;
    } finally {
        native.close();
    }
}

test "an external native project uses the bundled shared object runtime" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "hosted.jac";
        path.write_text(
            "import from jaclang.runtime.cpython.references { borrowed_result }\n"
                + "def:pub echo_object(value: u64) -> u64 { "
                + "return borrowed_result(value).take(); }\n"
        );
        program = JacProgram();
        module = program.compile(
            str(path),
            options=CompileOptions(force_codespace="native", force_target_program=True)
        );
        assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
        assert module is not None and module.gen.native_engine is not None;
        assert module.gen.native_engine.requires_python;
        echo_object = get_func(
            module.gen.native_engine, "echo_object", ctypes.c_void_p, ctypes.py_object
        );
        value = object();
        assert take(echo_object(value)) is value;
    }
}

test "generated Python stubs preserve interpreter state and errors" {
    program = JacProgram();
    path = str(Path(NATIVE_FIXTURES) / "python_hosted_entry.jac");
    module = program.compile(path, options=CompileOptions(default_codespace="server"));
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    assert module is not None and module.gen.native_engine is not None;
    assert module.gen.native_engine.requires_python;
    namespace: dict[str, any] = {
        "__jac_native_engine__": module.gen.native_engine,
        "__jac_interop_py_funcs__": module.gen.interop_py_funcs
    };
    exec(compile(module.gen.py, path, "exec"), namespace);
    assert namespace["server_call"]() == 1;
    try {
        namespace["hosted_failure"]();
    } except TypeError {} else {
        raise AssertionError("generated native stub lost the Python exception");
    }
}
