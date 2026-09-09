import sys;
import os;
import ctypes;
import from jaclang.compiler.backends.native.llvm.binding.common { _is_shutting_down }


def _shim_name -> str {
    if os.name == 'posix' {
        if sys.platform == 'darwin' {
            return 'libjacllvm.dylib';
        }
        return 'libjacllvm.so';
    }
    return 'jacllvm.dll';
}


def _find_shim -> str {
    import from jaclang.compiler.driver.compile_options { env_llvm_shim_override }
    `override = env_llvm_shim_override();
    if `override and (`override.strip().lower() in ("none", "off", "disabled")) {
        raise OSError(
            "LLVM shim disabled by JAC_LLVM_SHIM="
                + `override
                + "; the native pipeline is unavailable in this process."
        );
    }
    if `override and os.path.isfile(`override) {
        return `override;
    }
    shim = _shim_name();

    here = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(os.path.dirname(here), shim);
    if os.path.isfile(cand) {
        return cand;
    }

    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(
            p, 'jaclang', 'compiler', 'backends', 'native', 'llvm', shim
        );
        if os.path.isfile(alt) {
            return alt;
        }
        # Pre-reorg site layout: a host binary built before #8681 bundles
        # the shim under compiler/passes/native/, and the dev-source
        # reroute must still find it there.
        legacy = os.path.join(
            p, 'jaclang', 'compiler', 'passes', 'native', 'llvm', shim
        );
        if os.path.isfile(legacy) {
            return legacy;
        }
    }
    raise OSError(
        f"Could not locate the LLVM shim '{shim}'. Build it with "
            + "`zig build jacllvm` (artifact in jac/zig-out/lib/) and copy it next to "
            + "this package or set JAC_LLVM_SHIM; shipped binaries bundle it."
    );
}


class _MissingShimFunc {
    """Stands in for a shim function when no shim exists.

    Binding modules configure argtypes/restype at import time; without a
    shim those assignments land here and vanish, so the modules stay
    importable (the checker resolving an import must not demand LLVM).
    Only an actual call raises, with the original locate error."""
    def init(self: _MissingShimFunc, err: OSError) {
        self._err: OSError = err;
    }

    def __call__(self: _MissingShimFunc, *args: any, **kwargs: any) -> any {
        raise self._err;
    }
}


class _LazyLib {
    def init(self: _LazyLib) {
        self._handle: (ctypes.CDLL | None) = None;
    }

    def __getattr__(self: _LazyLib, name: str) -> any {
        if self._handle is None {
            try {
                self._handle = ctypes.CDLL(_find_shim());
            } except OSError as e {
                return _MissingShimFunc(e);
            }
        }
        return getattr(self._handle, name);
    }
}


glob lib = _LazyLib();


def _opaque(name: str) -> any {
    return ctypes.POINTER(`type(name, (ctypes.Structure, ), {}));
}


glob LLVMContextRef = _opaque("LLVMContext"),
     LLVMModuleRef = _opaque("LLVMModule"),
     LLVMValueRef = _opaque("LLVMValue"),
     LLVMTypeRef = _opaque("LLVMType"),
     LLVMExecutionEngineRef = _opaque("LLVMExecutionEngine"),
     LLVMPassManagerBuilderRef = _opaque("LLVMPassManagerBuilder"),
     LLVMPassManagerRef = _opaque("LLVMPassManager"),
     LLVMTargetDataRef = _opaque("LLVMTargetData"),
     LLVMTargetLibraryInfoRef = _opaque("LLVMTargetLibraryInfo"),
     LLVMTargetRef = _opaque("LLVMTarget"),
     LLVMTargetMachineRef = _opaque("LLVMTargetMachine"),
     LLVMMemoryBufferRef = _opaque("LLVMMemoryBuffer"),
     LLVMAttributeListIterator = _opaque("LLVMAttributeListIterator"),
     LLVMAttributeSetIterator = _opaque("LLVMAttributeSetIterator"),
     LLVMGlobalsIterator = _opaque("LLVMGlobalsIterator"),
     LLVMFunctionsIterator = _opaque("LLVMFunctionsIterator"),
     LLVMBlocksIterator = _opaque("LLVMBlocksIterator"),
     LLVMArgumentsIterator = _opaque("LLVMArgumentsIterator"),
     LLVMInstructionsIterator = _opaque("LLVMInstructionsIterator"),
     LLVMOperandsIterator = _opaque("LLVMOperandsIterator"),
     LLVMIncomingBlocksIterator = _opaque("LLVMIncomingBlocksIterator"),
     LLVMObjectCacheRef = _opaque("LLVMObjectCache"),
     LLVMObjectFileRef = _opaque("LLVMObjectFile"),
     LLVMSectionIteratorRef = _opaque("LLVMSectionIterator"),
     LLVMOrcLLJITRef = _opaque("LLVMOrcLLJITRef"),
     LLVMOrcDylibTrackerRef = _opaque("LLVMOrcDylibTrackerRef"),
     LLVMPipelineTuningOptionsRef = _opaque("LLVMPipeLineTuningOptions"),
     LLVMModulePassManagerRef = _opaque("LLVMModulePassManager"),
     LLVMFunctionPassManagerRef = _opaque("LLVMFunctionPassManager"),
     LLVMPassBuilderRef = _opaque("LLVMPassBuilder");


class _DeadPointer {}


class OutputString {
    @classmethod
    def from_return(cls: any, ptr: any) -> any {
        return cls(initval=ctypes.cast(ptr, ctypes.c_char_p));
    }

    def init(self: OutputString, owned: bool = True, initval: any = None) {
        self._ptr = initval if initval is not None else ctypes.c_char_p(None);
        self._as_parameter_ = ctypes.byref(self._ptr);
        self._owned = owned;
    }

    def close(self: OutputString) {
        if self._ptr is not None {
            if self._owned {
                lib.LLVMPY_DisposeString(self._ptr);
            }
            self._ptr = None;
            del self._as_parameter_;
        }
    }

    def __enter__(self: OutputString) -> any {
        return self;
    }

    def __exit__(self: OutputString, exc_type: any, exc_val: any, exc_tb: any) {
        self.close();
    }

    def __del__(self: OutputString) {
        try {
            if _is_shutting_down is not None and not _is_shutting_down() {
                self.close();
            }
        } except Exception {}
    }

    def __str__(self: OutputString) -> str {
        if self._ptr is None {
            return "<dead OutputString>";
        }
        s = self._ptr.value;
        assert s is not None;
        return bytes(s).decode('utf-8');
    }

    def __bool__(self: OutputString) -> bool {
        return bool(self._ptr);
    }

    has bytes: any {
        getter {
            return self._ptr.value;
        }
    }
}


def ret_string(ptr: any) -> any {
    if ptr is not None {
        return str(OutputString.from_return(ptr));
    }
    return None;
}


def ret_bytes(ptr: any) -> any {
    if ptr is not None {
        return OutputString.from_return(ptr).bytes;
    }
    return None;
}


class ObjectRef {
    def init(self: ObjectRef, ptr: any) {
        if ptr is None {
            raise ValueError("NULL pointer");
        }
        self._closed = False;
        self._owned = False;
        self._ptr = ptr;
        self._as_parameter_ = ptr;
        self._capi = lib;
    }

    def close(self: ObjectRef) {
        try {
            if not self._closed and not self._owned {
                self._dispose();
            }
        } finally {
            self.detach();
        }
    }

    def detach(self: ObjectRef) {
        if not self._closed {
            del self._as_parameter_;
            self._closed = True;
            self._ptr = None;
        }
    }

    def _dispose(self: ObjectRef) {}

    has closed: bool {
        getter {
            return self._closed;
        }
    }

    def __enter__(self: ObjectRef) -> any {
        if self._closed {
            raise RuntimeError(f"{self.__class__} instance already closed");
        }
        return self;
    }

    def __exit__(self: ObjectRef, exc_type: any, exc_val: any, exc_tb: any) {
        self.close();
    }

    def __del__(self: ObjectRef) {
        try {
            if _is_shutting_down is not None and not _is_shutting_down() {
                self.close();
            }
        } except Exception {}
    }

    def __bool__(self: ObjectRef) -> bool {
        return bool(self._ptr);
    }

    def __eq__(self: ObjectRef, other: any) -> bool {
        if not hasattr(other, "_ptr") {
            return False;
        }
        return ctypes.addressof(self._ptr[0]) == ctypes.addressof(other._ptr[0]);
    }

    def __hash__(self: ObjectRef) -> int {
        return hash(ctypes.cast(self._ptr, ctypes.c_void_p).value);
    }
}
