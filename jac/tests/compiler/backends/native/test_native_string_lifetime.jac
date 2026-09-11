"""Count live references, independently of RSS and allocator caching."""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF }
import from jaclang.compiler.native_compiler { ensure_loaded }

test "native string roots balance across locals fields loops and calls" {
    kernel = ensure_loaded();
    if kernel is None {
        return;
    }
    program = JacProgram();
    options = native_force_opts();
    options.memory_profile = "managed";
    options.no_ir_cache = True;
    mod = program.compile(
        os.path.join(TESTS_DIR, "compiler", "backends", "native", "fixtures",
            "rc_string_lifetime.jac"), options=options
    );
    assert not program.errors_had , [str(e) for e in program.errors_had];
    engine = mod.gen.native_engine;
    assert engine is not None;
    make = kernel.lib.jac_str_new;
    release = kernel.lib.jac_release;
    release.argtypes = [ctypes.c_void_p];
    release.restype = None;
    value = b"borrowed";
    for (name, copies) in [("local", 1), ("field", 1), ("loop", 3), ("call", 1)] {
        buffer_ptr = make(value, len(value));
        address = engine.get_function_address(name);
        assert address , f"missing fixture function {name}";
        fn = ctypes.CFUNCTYPE(
            ctypes.c_int64, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64
        )(address);
        try {
            assert fn(buffer_ptr, buffer_ptr, len(value)) == copies * len(value);
            refs = ctypes.c_int64.from_address(buffer_ptr + HDR_RC_OFF).value;
            assert refs == 1 , f"{name} left {refs} references to the input string";
        } finally {
            release(buffer_ptr);
        }
    }
}
