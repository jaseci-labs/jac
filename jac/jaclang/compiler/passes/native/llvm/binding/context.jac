import from jaclang.compiler.passes.native.llvm.binding { ffi }
def create_context() -> object {
    return ContextRef(ffi.lib.LLVMPY_ContextCreate());
}
def get_global_context() -> object {
    return GlobalContextRef(ffi.lib.LLVMPY_GetGlobalContext());
}
class ContextRef(ffi.ObjectRef) {
    def init(self: ContextRef, context_ptr: Any) -> object {
        super.init(context_ptr);
    }
    def _dispose(self: ContextRef) -> object {
        ffi.lib.LLVMPY_ContextDispose(self);
    }
}
class GlobalContextRef(ContextRef) {
    def _dispose(self: GlobalContextRef) -> object {
        ;
    }
}
with entry {
    ffi.lib.LLVMPY_GetGlobalContext.restype = ffi.LLVMContextRef;
    ffi.lib.LLVMPY_ContextCreate.restype = ffi.LLVMContextRef;
    ffi.lib.LLVMPY_ContextDispose.argtypes = [ffi.LLVMContextRef];
}

