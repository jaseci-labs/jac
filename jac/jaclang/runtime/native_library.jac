import ctypes;
import os;
import sys;

glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     _LOADED: dict[str, SharedNativeEngine] = {};

class SharedNativeEngine {
    def init(self: SharedNativeEngine, lib_path: str, record: dict) {
        mode = ctypes?.RTLD_LOCAL or 0;
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

    def enable_jit_events(self: SharedNativeEngine) {}
}

def shared_engine_for(lib_path: str, record: dict) -> SharedNativeEngine {
    key = os.path.realpath(lib_path);
    found = _LOADED.get(key);
    if found is None {
        found = SharedNativeEngine(key, record);
        _LOADED[key] = found;
    }
    return found;
}
