"""A sealed app's native artifact as an engine.

The Python side of a native module calls native code through an engine's
`get_function_address`. In a source tree that engine is the link plan's
in-process JIT; in a sealed app it is the one shared library the seal
linked from the package's native units, loaded here through `ctypes` and
presented under the same surface (`get_function_address`,
`get_global_value_address`, `static_init_symbols`, `run_static_init`), so
the interop stubs the compiler emitted and the meta importer are unchanged.

The library's `__jac_shared_init` runs every unit's initializer in the
plan's order; it is called once, on the first address handed out. Native
imports of Python functions bind through the JIT's symbol table and are not
served by a sealed artifact.
"""
import ctypes;
import os;
import sys;

glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     _LOADED: dict[str, SharedNativeEngine] = {};

class SharedNativeEngine {
    def init(self: SharedNativeEngine, lib_path: str, record: dict) {
        mode = ctypes.RTLD_GLOBAL if hasattr(ctypes, "RTLD_GLOBAL") else 0;
        self.lib_path = lib_path;
        self.record = dict(record);
        self.lib = ctypes.CDLL(lib_path, mode=mode);
        self.static_init_symbols: list[str] = [SHARED_INIT_SYMBOL];
        self.static_init_chained: set[str] = {"jac_entry"};
        self._initialized = False;
    }

    def _address_of(self: SharedNativeEngine, name: str) -> int {
        try {
            fn = getattr(self.lib, name);
        } except AttributeError {
            return 0;
        }
        return ctypes.cast(fn, ctypes.c_void_p).value or 0;
    }

    """Run the library's initializer once."""
    def run_static_init(self: SharedNativeEngine) -> None {
        if self._initialized {
            return;
        }
        self._initialized = True;
        for symbol in self.static_init_symbols {
            addr = self._address_of(symbol);
            if addr {
                ctypes.CFUNCTYPE(None)(addr)();
            }
        }
        self.static_init_symbols = [];
    }

    def get_function_address(self: SharedNativeEngine, name: str) -> int {
        if not self._initialized and name not in self.static_init_chained {
            self.run_static_init();
        }
        return self._address_of(name);
    }

    def get_global_value_address(self: SharedNativeEngine, name: str) -> int {
        return self._address_of(name);
    }

    def enable_jit_events(self: SharedNativeEngine) -> None {}
}

"""The engine over the artifact at `lib_path`, loaded once per process."""
def shared_engine_for(lib_path: str, record: dict) -> SharedNativeEngine {
    key = os.path.realpath(lib_path);
    found = _LOADED.get(key);
    if found is None {
        found = SharedNativeEngine(key, record);
        _LOADED[key] = found;
    }
    return found;
}
