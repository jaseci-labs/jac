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
