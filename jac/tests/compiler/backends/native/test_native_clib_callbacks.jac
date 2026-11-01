"""C callback arguments adapt scalar widths and reject boxed Jac callables."""
import ctypes;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from tests.support { KernelFixture, compile_native, get_func, kernel_compile_source, warning_codes, write_case }
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""`compile_native` under explicit options: kernel compile, then JIT the
unit in this process."""
def compile_native_with(
    fixture: str, options: CompileOptions, fixture_dir: str = ""
) -> tuple[any, KernelFixture] {
    return compile_native(fixture, fixture_dir, options);
}

test "C callback arguments sign-extend the C integer before calling Jac" {
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_int32);
    invoke_type = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_void_p, ctypes.c_int32);
    def invoke(address: int, value: int) -> int {
        return callback_type(address)(value);
    }
    foreign = invoke_type(invoke);
    llvm.add_symbol("clib_invoke_i32", ctypes.cast(foreign, ctypes.c_void_p).value);
    (engine, _) = compile_native("clib_callback_argument.jac");
    function = get_func(engine, "call_signed", ctypes.c_int32);
    assert function() == 123;
}

test "C function pointers from records adapt Jac callback arguments" {
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_int32);
    invoke_type = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_void_p, ctypes.c_int32);
    def invoke(address: int, value: int) -> int {
        return callback_type(address)(value);
    }
    foreign = invoke_type(invoke);
    (engine, _) = compile_native("clib_record_callback_argument.jac");
    function = get_func(engine, "call_through_record", ctypes.c_int32, ctypes.c_int64);
    assert function(ctypes.cast(foreign, ctypes.c_void_p).value) == 123;
}

test "nullable Jac callbacks cannot become untyped C code addresses" {
    result = kernel_compile_source(
        "import from c { def invoke_c(cb: Callable[[i32], i32], value: i32) -> i32; }\n"
            + "obj Handler { has callback: Callable[[i32], i32] | None; }\n"
            + "def invoke(handler: Handler) -> i32 { cb = handler.callback; "
            + "if cb is None { return 0; } return invoke_c(cb, 7); }\n",
        "nullable_c_callback.jac",
        CompileOptions(aot_mode=True, native_required=True)
    );
    assert any("function pointer" in error.message for error in result.errors) , (
        "A nullable Jac callable must not be cast to an arbitrary C address"
    );
}

test "C callback records have layout-compatible pointer fields" {
    result = kernel_compile_source(
        "import from c { obj Callbacks { has call: Callable[[i32], i32] = 0; } }\n"
            + "def signed(value: i32) -> i32 { return value; }\n"
            + "glob callbacks = Callbacks(call=signed);\n",
        "callback_record_layout.jac",
        CompileOptions(no_cgen=True, native_required=True)
    );
    assert result.ok() , str([error.message for error in result.errors]);
    assert "W5032" not in warning_codes(result);
}


test "C callback records accept addresses from dynamic symbol lookup" {
    library = ctypes.CDLL(None);
    address = ctypes.cast(library.abs, ctypes.c_void_p).value;
    assert isinstance(address, int);
    (engine, _) = compile_native_with(
        write_case(
            "import from c { obj Functions { has absolute: Callable[[i32], i32] = 0; } }\n"
                + "def invoke_address(address: int, value: i32) -> i32 { "
                + "functions = Functions(); functions.absolute = address; "
                + "return functions.absolute(value); }\n",
            "dynamic_c_callback.jac"
        ),
        CompileOptions(force_codespace="native", native_required=True)
    );
    function = get_func(
        engine, "invoke_address", ctypes.c_int32, ctypes.c_int64, ctypes.c_int32
    );
    assert function(address, -123) == 123;
}

test "Callback records survive managed field and container cleanup" {
    import mmap;
    import os;
    if not hasattr(os, "fork") {
        testskip("guard-page lifetime probe requires fork");
    }
    library = ctypes.CDLL(None);
    library.mprotect.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int];
    library.mprotect.restype = ctypes.c_int;
    storage = mmap.mmap(-1, mmap.PAGESIZE * 2);
    buffer: any = ctypes.c_char.from_buffer(storage);
    address = ctypes.addressof(buffer);
    del buffer;
    assert library.mprotect(address, mmap.PAGESIZE, 0) == 0;
    allocator_type = ctypes.CFUNCTYPE(
        ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t
    );
    original = ctypes.cast(library.calloc, ctypes.c_void_p).value;
    library.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t];
    library.calloc.restype = ctypes.c_void_p;
    guarded: list[bool] = [False];
    def allocate(count: int, size: int) -> int {
        if guarded[0] and count * size <= mmap.PAGESIZE {
            return address + mmap.PAGESIZE;
        }
        return library.calloc(count, size) or 0;
    }
    allocator = allocator_type(allocate);
    try {
        llvm.add_symbol("calloc", ctypes.cast(allocator, ctypes.c_void_p).value);
        (engine, _) = compile_native_with(
            write_case(
                "import from c { obj Callbacks { has call: Callable[[i32], i32] = 0; } }\n"
                    + "obj Holder { has callback: Callbacks, optional: Callbacks | None; }\n"
                    + "def signed(value: i32) -> i32 { return value; }\n"
                    + "def probe -> i32 { cb = Callbacks(call=signed); "
                    + "holders = [Holder(cb, cb)]; callbacks = [cb]; "
                    + "value = holders[0].callback.call(-7) + callbacks[0].call(7); "
                    + "holders.clear(); callbacks.clear(); return cb.call(value); }\n",
                "callback_record_lifetime.jac"
            ),
            CompileOptions(force_codespace="native", native_required=True)
        );
        function = get_func(engine, "probe", ctypes.c_int32);
        child = os.fork();
        if child == 0 {
            guarded[0] = True;
            os._exit(0 if function() == 0 else 1);
        }
        (_, status) = os.waitpid(child, 0);
        assert os.waitstatus_to_exitcode(status) == 0 , (
            "Managed callback cleanup read outside the record allocation"
        );
    } finally {
        llvm.add_symbol("calloc", original);
        library.mprotect(address, mmap.PAGESIZE, mmap.PROT_READ | mmap.PROT_WRITE);
        storage.close();
    }
}

test "Python property registration lowers with C ABI callbacks" {
    import from pathlib { Path }
    import from tests.support { JAC_ROOT, compile_native_ir }
    bindings = Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "bindings";
    fx = compile_native_ir("type.jac", fixture_dir=str(bindings));
    assert fx.llvm_ir();
}
