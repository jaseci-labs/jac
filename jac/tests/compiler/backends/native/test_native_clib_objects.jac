"""Foreign signatures resolve native Jac objects and consume owned returns."""
import ctypes;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from tests.support { compile_native, get_func }

test "C callbacks preserve local and imported Jac object types and ownership" {
    retainers: dict[str, any] = {};
    def local_callback(pointer: int) -> int {
        return retainers["local"](pointer);
    }
    def imported_callback(pointer: int) -> int {
        return retainers["imported"](pointer);
    }
    callback_type = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p);
    local = callback_type(local_callback);
    imported = callback_type(imported_callback);
    llvm.add_symbol("echo_local_packet", ctypes.cast(local, ctypes.c_void_p).value);
    llvm.add_symbol(
        "echo_imported_packet", ctypes.cast(imported, ctypes.c_void_p).value
    );
    (engine, _) = compile_native("clib_jac_object.jac");
    retainers["local"] = get_func(
        engine, "retain_local_packet", ctypes.c_void_p, ctypes.c_void_p
    );
    retainers["imported"] = get_func(
        engine, "retain_imported_packet", ctypes.c_void_p, ctypes.c_void_p
    );
    roundtrip = get_func(engine, "roundtrip", ctypes.c_int64);
    drops = get_func(engine, "drop_count", ctypes.c_int32);
    for i in range(25) {
        assert roundtrip() == 42;
        assert drops() == (i + 1) * 2;
    }
}
