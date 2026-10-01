import ctypes;
import os;
import from ctypes { c_char_p, c_int64, c_void_p, cast, py_object }

class NativeCompiler {
    def init(self: NativeCompiler, lib_path: str) {
        self.lib = ctypes.PyDLL(lib_path);
        self.lib_path = lib_path;
        self.lib.jac_str_new.argtypes = [c_char_p, c_int64];
        self.lib.jac_str_new.restype = c_void_p;
        self.lib.jac_release.argtypes = [c_void_p];
        self.lib.jac_release.restype = None;
    }

    def _take(self: NativeCompiler, ptr: any) -> any {
        if not ptr {
            return None;
        }
        boxed = cast(ptr, py_object);
        out = boxed.value;
        ctypes.pythonapi.Py_DecRef(c_void_p(ptr));
        return out;
    }
}

glob _KERNEL_CELL: list[any] = [],
     _RESOLVED: list[any] = [],
     _RESOLVING: list[any] = [],
     _LOADED: dict[str, NativeCompiler] = {};

def ensure_loaded -> (NativeCompiler | None) {
    if _KERNEL_CELL {
        return _KERNEL_CELL[0];
    }
    if _RESOLVED or _RESOLVING {
        return None;
    }
    import sys;
    resolver = sys.modules.get("jaclang.compiler.backends.native.kernel_resolve");
    if resolver is not None and not hasattr(resolver, "resolve_kernel") {
        return None;
    }
    _RESOLVING.append(1);
    try {
        import from jaclang.compiler.backends.native.kernel_resolve { resolve_kernel }
        found = resolve_kernel();
    } finally {
        _RESOLVING.clear();
    }
    if found is None {
        _RESOLVED.append(None);
        return None;
    }
    lib_path = os.path.realpath(found.lib_path);
    k = _LOADED.get(lib_path);
    if k is None {
        k = NativeCompiler(lib_path);
        _LOADED[lib_path] = k;
    }
    _KERNEL_CELL.append(k);
    return k;
}

def reset_loaded {
    _KERNEL_CELL.clear();
    _RESOLVED.clear();
    _RESOLVING.clear();
}
