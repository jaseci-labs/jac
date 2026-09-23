"""C callback arguments adapt scalar widths and reject boxed Jac callables."""
import ctypes;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from tests.support { compile_native, get_func }

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

test "nullable Jac callbacks cannot become untyped C code addresses" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    program.compile(
        file_path="nullable_c_callback.jac",
        use_str="import from c { def invoke_c(cb: Callable[[i32], i32], value: i32) -> i32; }\n"
            + "obj Handler { has callback: Callable[[i32], i32] | None; }\n"
            + "def invoke(handler: Handler) -> i32 { cb = handler.callback; "
            + "if cb is None { return 0; } return invoke_c(cb, 7); }\n",
        options=CompileOptions(aot_mode=True, native_required=True)
    );
    assert any("function pointer" in str(error) for error in program.errors_had) , (
        "A nullable Jac callable must not be cast to an arbitrary C address"
    );
}

test "C callback records have layout-compatible pointer fields" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    program.compile(
        file_path="callback_record_layout.jac",
        use_str="import from c { obj Callbacks { has call: Callable[[i32], i32] = 0; } }\n"
            + "def signed(value: i32) -> i32 { return value; }\n"
            + "glob callbacks = Callbacks(call=signed);\n",
        options=CompileOptions(no_cgen=True, native_required=True)
    );
    assert not program.errors_had , str(program.errors_had);
    assert not any(
        error.code is not None and error.code.code == "W5032"
        for error in program.warnings_had
    );
}


test "C callback records accept addresses from dynamic symbol lookup" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    library = ctypes.CDLL(None);
    address = ctypes.cast(library.abs, ctypes.c_void_p).value;
    assert isinstance(address, int);
    program = JacProgram();
    module = program.compile(
        file_path="dynamic_c_callback.jac",
        use_str="import from c { obj Functions { has absolute: Callable[[i32], i32] = 0; } }\n"
            + "def invoke_address(address: int, value: i32) -> i32 { "
            + "functions = Functions(); functions.absolute = address; "
            + "return functions.absolute(value); }\n",
        options=CompileOptions(native_required=True)
    );
    assert not program.errors_had , str(program.errors_had);
    engine = module.gen.native_engine;
    assert engine is not None;
    function = get_func(
        engine, "invoke_address", ctypes.c_int32, ctypes.c_int64, ctypes.c_int32
    );
    assert function(address, -123) == 123;
}

test "Callback records survive managed field and container cleanup" {
    import mmap;
    import os;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
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
    def allocate(count: int, size: int) -> int {
        assert count * size <= mmap.PAGESIZE;
        return address + mmap.PAGESIZE;
    }
    allocator = allocator_type(allocate);
    original = ctypes.cast(library.calloc, ctypes.c_void_p).value;
    try {
        llvm.add_symbol("calloc", ctypes.cast(allocator, ctypes.c_void_p).value);
        program = JacProgram();
        module = program.compile(
            file_path="callback_record_lifetime.jac",
            use_str="import from c { obj Callbacks { has call: Callable[[i32], i32] = 0; } }\n"
                + "obj Holder { has callback: Callbacks, optional: Callbacks | None; }\n"
                + "def signed(value: i32) -> i32 { return value; }\n"
                + "def probe -> i32 { cb = Callbacks(call=signed); "
                + "holders = [Holder(cb, cb)]; callbacks = [cb]; "
                + "value = holders[0].callback.call(-7) + callbacks[0].call(7); "
                + "holders.clear(); callbacks.clear(); return cb.call(value); }\n",
            options=CompileOptions(native_required=True)
        );
        assert not program.errors_had , str(program.errors_had);
        function = get_func(module.gen.native_engine, "probe", ctypes.c_int32);
        child = os.fork();
        if child == 0 {
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
    module = compile_native_ir("type.jac", fixture_dir=str(bindings));
    assert module.gen.llvm_ir is not None;
}
