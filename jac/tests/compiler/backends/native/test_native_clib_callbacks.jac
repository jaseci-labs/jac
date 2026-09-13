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
        options=CompileOptions(
            aot_mode=True, native_required=True, force_target_program=True
        )
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
        options=CompileOptions(
            no_cgen=True, native_required=True, force_target_program=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
    assert not any(
        error.code is not None and error.code.code == "W5032"
        for error in program.warnings_had
    );
}
