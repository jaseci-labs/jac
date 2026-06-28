"""FFI loader for the in-tree LLVM binding (Jac port, #6925).

Hand-authored (the original llvmlite/binding/ffi.py uses __slots__/__getattr__
dynamic dispatch and a thread-lock wrapper). Loads the Zig-built LLVMPY_* shim
(libjacllvm.so, jac/native statically linked against LLVM) via ctypes -- no
llvmlite wheel involved.

The na compile path is single-threaded, so the per-call lock wrapper is
dropped: a plain ctypes.CDLL caches its function pointers, so
`lib.LLVMPY_X.argtypes = [...]` then `lib.LLVMPY_X(...)` works directly.
"""

import sys;
import os;
import ctypes;
import from jaclang.compiler.passes.native.llvm.binding.common { _decode_string, _is_shutting_down }


def _shim_name() -> str {
    if os.name == 'posix' {
        if sys.platform == 'darwin' {
            return 'libjacllvm.dylib';
        }
        return 'libjacllvm.so';
    }
    return 'jacllvm.dll';
}


"""Locate the Zig-built LLVMPY_* shim (libjacllvm.so) to ctypes-load.

Resolution order: (1) JAC_LLVM_SHIM override (set by dev/CI to the build
artifact, e.g. jac/zig-out/lib/libjacllvm.so); (2) the shim shipped next to this
package at jaclang/compiler/passes/native/llvm/, located relative to
`jaclang.__file__` -- works both in the editable source tree (where the dir is
not on sys.path) and in the packed payload. No llvmlite wheel fallback: the
package is fully decoupled (#6925)."""
def _find_shim() -> str {
    override = os.environ.get('JAC_LLVM_SHIM', None);
    if override and os.path.isfile(override) {
        return override;
    }
    shim = _shim_name();
    # The shim sits one dir up from this binding/ module, at native/llvm/<shim>.
    # __file__-relative works in the editable tree (its dir is not on sys.path).
    here = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(os.path.dirname(here), shim);
    if os.path.isfile(cand) {
        return cand;
    }
    # Payload fallback: the bundled site/ is on sys.path.
    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, 'jaclang', 'compiler', 'passes', 'native', 'llvm', shim);
        if os.path.isfile(alt) {
            return alt;
        }
    }
    raise OSError(
        f"Could not locate the LLVM shim '{shim}'. Build it with "
        + "`zig build jacllvm` (artifact in jac/zig-out/lib/) and copy it next to "
        + "this package or set JAC_LLVM_SHIM; shipped binaries bundle it."
    );
}


"""Lazy CDLL proxy: loads libjacllvm.so (~130 MB) on first symbol access, not
at import. Mirrors a lazy lib wrapper so processes that merely
type-import the binding (e.g. codeinfo's ModuleRef/ExecutionEngine) never map
the shared object. ctypes caches function pointers on the handle, so
`lib.LLVMPY_X.argtypes = [...]` then `lib.LLVMPY_X(...)` still works."""
class _LazyLib {
    def init(self: _LazyLib) {
        self._handle = None;
    }

    def __getattr__(self: _LazyLib, name: str) -> Any {
        if self._handle is None {
            self._handle = ctypes.CDLL(_find_shim());
        }
        return getattr(self._handle, name);
    }
}


glob lib = _LazyLib();


def _opaque(name: str) -> Any {
    return ctypes.POINTER(`type(name, (ctypes.Structure, ), {}));
}


glob LLVMContextRef = _opaque("LLVMContext");
glob LLVMModuleRef = _opaque("LLVMModule");
glob LLVMValueRef = _opaque("LLVMValue");
glob LLVMTypeRef = _opaque("LLVMType");
glob LLVMExecutionEngineRef = _opaque("LLVMExecutionEngine");
glob LLVMPassManagerBuilderRef = _opaque("LLVMPassManagerBuilder");
glob LLVMPassManagerRef = _opaque("LLVMPassManager");
glob LLVMTargetDataRef = _opaque("LLVMTargetData");
glob LLVMTargetLibraryInfoRef = _opaque("LLVMTargetLibraryInfo");
glob LLVMTargetRef = _opaque("LLVMTarget");
glob LLVMTargetMachineRef = _opaque("LLVMTargetMachine");
glob LLVMMemoryBufferRef = _opaque("LLVMMemoryBuffer");
glob LLVMAttributeListIterator = _opaque("LLVMAttributeListIterator");
glob LLVMElementIterator = _opaque("LLVMElementIterator");
glob LLVMAttributeSetIterator = _opaque("LLVMAttributeSetIterator");
glob LLVMGlobalsIterator = _opaque("LLVMGlobalsIterator");
glob LLVMFunctionsIterator = _opaque("LLVMFunctionsIterator");
glob LLVMBlocksIterator = _opaque("LLVMBlocksIterator");
glob LLVMArgumentsIterator = _opaque("LLVMArgumentsIterator");
glob LLVMInstructionsIterator = _opaque("LLVMInstructionsIterator");
glob LLVMOperandsIterator = _opaque("LLVMOperandsIterator");
glob LLVMIncomingBlocksIterator = _opaque("LLVMIncomingBlocksIterator");
glob LLVMTypesIterator = _opaque("LLVMTypesIterator");
glob LLVMObjectCacheRef = _opaque("LLVMObjectCache");
glob LLVMObjectFileRef = _opaque("LLVMObjectFile");
glob LLVMSectionIteratorRef = _opaque("LLVMSectionIterator");
glob LLVMOrcLLJITRef = _opaque("LLVMOrcLLJITRef");
glob LLVMOrcDylibTrackerRef = _opaque("LLVMOrcDylibTrackerRef");
glob LLVMTimePassesHandlerRef = _opaque("LLVMTimePassesHandler");
glob LLVMPipelineTuningOptionsRef = _opaque("LLVMPipeLineTuningOptions");
glob LLVMModulePassManagerRef = _opaque("LLVMModulePassManager");
glob LLVMFunctionPassManagerRef = _opaque("LLVMFunctionPassManager");
glob LLVMPassBuilderRef = _opaque("LLVMPassBuilder");


class _DeadPointer {}


"""Object for managing the char* output of LLVM APIs (out-param error strings)."""
class OutputString {

    @classmethod
    def from_return(cls: Any, ptr: Any) -> Any {
        return cls(initval=ctypes.cast(ptr, ctypes.c_char_p));
    }

    def init(self: OutputString, owned: bool = True, initval: Any = None) {
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

    def __enter__(self: OutputString) -> Any {
        return self;
    }

    def __exit__(self: OutputString, exc_type: Any, exc_val: Any, exc_tb: Any) {
        self.close();
    }

    def __del__(self: OutputString) {
        try {
            if _is_shutting_down is not None and not _is_shutting_down() {
                self.close();
            }
        } except Exception {
            ;
        }
    }

    def __str__(self: OutputString) -> str {
        if self._ptr is None {
            return "<dead OutputString>";
        }
        s = self._ptr.value;
        assert s is not None;
        return _decode_string(s);
    }

    def __bool__(self: OutputString) -> bool {
        return bool(self._ptr);
    }

    # Raw bytes of the char pointer content.
    @property
    def bytes(self: OutputString) -> Any {
        return self._ptr.value;
    }
}


def ret_string(ptr: Any) -> Any {
    if ptr is not None {
        return str(OutputString.from_return(ptr));
    }
    return None;
}


def ret_bytes(ptr: Any) -> Any {
    if ptr is not None {
        return OutputString.from_return(ptr).bytes;
    }
    return None;
}


"""A wrapper around a ctypes pointer to an LLVM object ('resource')."""
class ObjectRef {

    def init(self: ObjectRef, ptr: Any) {
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

    def _dispose(self: ObjectRef) {
        ;
    }

    @property
    def closed(self: ObjectRef) -> bool {
        return self._closed;
    }

    def __enter__(self: ObjectRef) -> Any {
        if self._closed {
            raise RuntimeError(f"{self.__class__} instance already closed");
        }
        return self;
    }

    def __exit__(self: ObjectRef, exc_type: Any, exc_val: Any, exc_tb: Any) {
        self.close();
    }

    def __del__(self: ObjectRef) {
        try {
            if _is_shutting_down is not None and not _is_shutting_down() {
                self.close();
            }
        } except Exception {
            ;
        }
    }

    def __bool__(self: ObjectRef) -> bool {
        return bool(self._ptr);
    }

    def __eq__(self: ObjectRef, other: Any) -> bool {
        if not hasattr(other, "_ptr") {
            return False;
        }
        return ctypes.addressof(self._ptr[0]) == ctypes.addressof(other._ptr[0]);
    }

    def __hash__(self: ObjectRef) -> int {
        return hash(ctypes.cast(self._ptr, ctypes.c_void_p).value);
    }
}
