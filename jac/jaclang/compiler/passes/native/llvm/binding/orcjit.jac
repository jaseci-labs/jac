import ctypes;
import from ctypes { POINTER, c_bool, c_char_p, c_uint8, c_uint64, c_size_t }
import from jaclang.compiler.passes.native.llvm.binding { ffi, targets }
class _LinkElement(ctypes.Structure) {
    with entry {
        _fields_ = [
            ("element_kind", c_uint8),
            ("value", c_char_p),
            ("value_len", c_size_t)
        ];
    }
}

class _SymbolAddress(ctypes.Structure) {
    with entry {
        _fields_ = [("name", c_char_p), ("address", c_uint64)];
    }
}


class JITLibraryBuilder {
    def init(self: JITLibraryBuilder) -> object {
        self.__entries = [];
        self.__exports = `set();
        self.__imports = {};
    }

    def add_ir(self: JITLibraryBuilder, llvmir: Any) -> object {
        self.__entries.append((0, str(llvmir).encode('utf-8')));
        return self;
    }

    def add_native_assembly(self: JITLibraryBuilder, asm: Any) -> object {
        self.__entries.append((1, str(asm).encode('utf-8')));
        return self;
    }

    def add_object_img(self: JITLibraryBuilder, data: Any) -> object {
        self.__entries.append((2, `bytes(data)));
        return self;
    }

    def add_object_file(self: JITLibraryBuilder, file_path: Any) -> object {
        with open(file_path, "rb") as f {
            self.__entries.append((2, f.read()));
        }
        return self;
    }

    def add_jit_library(self: JITLibraryBuilder, name: Any) -> object {
        self.__entries.append((3, str(name).encode('utf-8')));
        return self;
    }

    def add_current_process(self: JITLibraryBuilder) -> object {
        self.__entries.append((3, b''));
        return self;
    }

    def import_symbol(self: JITLibraryBuilder, name: Any, address: Any) -> object {
        self.__imports[str(name)] = c_uint64(address);
        return self;
    }

    def export_symbol(self: JITLibraryBuilder, name: Any) -> object {
        self.__exports.add(str(name));
        return self;
    }

    def link(self: JITLibraryBuilder, lljit: Any, library_name: Any) -> object {
        assert not lljit.closed , "Cannot add to closed JIT";
        encoded_library_name = str(library_name).encode('utf-8');
        assert (len(encoded_library_name) > 0) , "Library cannot be empty";
        elements = (_LinkElement * len(self.__entries))();
        for (idx, (kind, value)) in enumerate(self.__entries) {
            elements[idx].element_kind = c_uint8(kind);
            elements[idx].value = c_char_p(value);
            elements[idx].value_len = c_size_t(len(value));
        }
        exports = (_SymbolAddress * len(self.__exports))();
        for (idx, name) in enumerate(self.__exports) {
            exports[idx].name = name.encode('utf-8');
        }
        imports = (_SymbolAddress * len(self.__imports))();
        for (idx, (name, addr)) in enumerate(self.__imports.items()) {
            imports[idx].name = name.encode('utf-8');
            imports[idx].address = addr;
        }
        with ffi.OutputString() as outerr {
            tracker = lljit._capi.LLVMPY_LLJIT_Link(
                lljit._ptr,
                encoded_library_name,
                elements,
                len(self.__entries),
                imports,
                len(self.__imports),
                exports,
                len(self.__exports),
                outerr
            );
            if not tracker {
                raise RuntimeError(str(outerr));
            }
        }
        return ResourceTracker(
            tracker,
            library_name,
            {name: exports[idx].address for (idx, name) in enumerate(self.__exports)}
        );
    }
}


class ResourceTracker(ffi.ObjectRef) {
    def init(self: ResourceTracker, ptr: Any, name: Any, addresses: Any) -> object {
        self.__addresses = addresses;
        self.__name = name;
        ffi.ObjectRef.init(self, ptr);
    }

    def __getitem__(self: ResourceTracker, item: Any) -> object {
        return self.__addresses[item];
    }

    @property
    def name(self: ResourceTracker) -> object {
        return self.__name;
    }

    def _dispose(self: ResourceTracker) -> object {
        with ffi.OutputString() as outerr {
            if self._capi.LLVMPY_LLJIT_Dylib_Tracker_Dispose(self, outerr) {
                raise RuntimeError(str(outerr));
            }
        }
    }
}


class LLJIT(ffi.ObjectRef) {
    def init(self: LLJIT, ptr: Any) -> object {
        self._td = None;
        ffi.ObjectRef.init(self, ptr);
    }

    def lookup(self: LLJIT, dylib: Any, fn: Any) -> object {
        assert not self.closed , "Cannot lookup in closed JIT";
        address = ctypes.c_uint64();
        with ffi.OutputString() as outerr {
            tracker = ffi.lib.LLVMPY_LLJITLookup(
                self,
                dylib.encode("utf-8"),
                fn.encode("utf-8"),
                ctypes.byref(address),
                outerr
            );
            if not tracker {
                raise RuntimeError(str(outerr));
            }
        }
        return ResourceTracker(tracker, dylib, {fn: address.value});
    }

    @property
    def target_data(self: LLJIT) -> object {
        if (self._td is not None) {
            return self._td;
        }
        ptr = ffi.lib.LLVMPY_LLJITGetDataLayout(self);
        self._td = targets.TargetData(ptr);
        self._td._owned = True;
        return self._td;
    }

    def _dispose(self: LLJIT) -> object {
        if (self._td is not None) {
            self._td.detach();
        }
        self._capi.LLVMPY_LLJITDispose(self);
    }
}

def create_lljit_compiler(
    target_machine: Any = None,
    *,
    use_jit_link: Any = False,
    suppress_errors: Any = False
) -> object {
    with ffi.OutputString() as outerr {
        lljit = ffi.lib.LLVMPY_CreateLLJITCompiler(
            target_machine, suppress_errors, use_jit_link, outerr
        );
        if not lljit {
            raise RuntimeError(str(outerr));
        }
    }
    return LLJIT(lljit);
}

with entry {
    ffi.lib.LLVMPY_LLJITLookup.argtypes = [
        ffi.LLVMOrcLLJITRef,
        c_char_p,
        c_char_p,
        POINTER(c_uint64),
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_LLJITLookup.restype = ffi.LLVMOrcDylibTrackerRef;
    ffi.lib.LLVMPY_LLJITGetDataLayout.argtypes = [ffi.LLVMOrcLLJITRef];
    ffi.lib.LLVMPY_LLJITGetDataLayout.restype = ffi.LLVMTargetDataRef;
    ffi.lib.LLVMPY_CreateLLJITCompiler.argtypes = [
        ffi.LLVMTargetMachineRef,
        c_bool,
        c_bool,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_CreateLLJITCompiler.restype = ffi.LLVMOrcLLJITRef;
    ffi.lib.LLVMPY_LLJITDispose.argtypes = [ffi.LLVMOrcLLJITRef];
    ffi.lib.LLVMPY_LLJIT_Link.argtypes = [
        ffi.LLVMOrcLLJITRef,
        c_char_p,
        POINTER(_LinkElement),
        c_size_t,
        POINTER(_SymbolAddress),
        c_size_t,
        POINTER(_SymbolAddress),
        c_size_t,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_LLJIT_Link.restype = ffi.LLVMOrcDylibTrackerRef;
    ffi.lib.LLVMPY_LLJIT_Dylib_Tracker_Dispose.argtypes = [
        ffi.LLVMOrcDylibTrackerRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_LLJIT_Dylib_Tracker_Dispose.restype = c_bool;
}
