def create_context -> object {
    return ContextRef(ffi.lib.LLVMPY_ContextCreate());
}

def get_global_context -> object {
    return GlobalContextRef(ffi.lib.LLVMPY_GetGlobalContext());
}

"""A context outlives every module it owns.

Disposing a context frees its modules, and the cycle collector finalizes a
module and its context in either order, so the context is disposed by
whichever of the two goes last: its own close, or its last module's."""
class ContextRef(ffi.ObjectRef) {
    def init(self: ContextRef, context_ptr: any) -> object {
        super.init(context_ptr);
        self._handle = context_ptr;
        self._live_modules = 0;
        self._released = False;
    }

    def _adopt_module(self: ContextRef) {
        self._live_modules += 1;
    }

    def _release_module(self: ContextRef) {
        self._live_modules -= 1;
        if self._released and self._live_modules == 0 {
            self._dispose_handle();
        }
    }

    def _dispose(self: ContextRef) -> object {
        self._released = True;
        if self._live_modules == 0 {
            self._dispose_handle();
        }
    }

    def _dispose_handle(self: ContextRef) {
        if self._handle is not None {
            ffi.lib.LLVMPY_ContextDispose(self._handle);
            self._handle = None;
        }
    }
}

class GlobalContextRef(ContextRef) {
    def _dispose_handle(self: GlobalContextRef) {}
}

with entry {
    ffi.lib.LLVMPY_GetGlobalContext.restype = ffi.LLVMContextRef;
    ffi.lib.LLVMPY_ContextCreate.restype = ffi.LLVMContextRef;
    ffi.lib.LLVMPY_ContextDispose.argtypes = [ffi.LLVMContextRef];
}
