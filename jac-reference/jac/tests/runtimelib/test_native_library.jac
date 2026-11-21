"""The sealed application engine presents the JIT engine's surface (#8943).

A sealed app with native pins runs its linked artifact through a ctypes
engine with the same surface as the in-process JIT: function and global
addresses, the static initializer list, and the chained entry symbol. The
seal record test covers a real artifact; this pins the surface itself against
the host's C library, which every host has.
"""
import ctypes;
import ctypes.util;
import from unittest { SkipTest }
import from jaclang.runtime.native_library { SharedNativeEngine, SHARED_INIT_SYMBOL }

def _libc -> SharedNativeEngine {
    name = ctypes.util.find_library("c");
    if name is None {
        raise SkipTest("no C library on this host");
    }
    return SharedNativeEngine(name, {"path": name});
}

test "function addresses come from the library and missing symbols are zero" {
    engine = _libc();
    address = engine.get_function_address("strlen");
    assert address;
    strlen = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_char_p)(address);
    assert strlen(b"hello") == 5;
    assert engine.get_function_address("jac_symbol_that_does_not_exist") == 0;
    assert engine.get_global_value_address("jac_symbol_that_does_not_exist") == 0;
}

test "the first function lookup runs static initialization once" {
    engine = _libc();
    assert not engine._initialized;
    assert engine.static_init_symbols == [SHARED_INIT_SYMBOL];
    assert engine.get_function_address("jac_entry") == 0;
    assert not engine._initialized , "the chained entry symbol never triggers initialization";
    engine.get_function_address("strlen");
    assert engine._initialized;
    assert engine.static_init_symbols == [];
    engine.run_static_init();
    assert engine.static_init_symbols == [];
}

test "global lookups do not initialize and the JIT event hook is inert" {
    engine = _libc();
    assert engine.get_global_value_address("strlen");
    assert not engine._initialized;
    engine.enable_jit_events();
    assert engine.record == {"path": engine.lib_path};
}
