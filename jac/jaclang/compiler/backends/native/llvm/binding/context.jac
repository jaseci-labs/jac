class ContextRef(ObjectRef) {
    def _dispose(self: ContextRef) {
        LLVMPY_ContextDispose(self.handle);
    }
}

class GlobalContextRef(ContextRef) {
    def _dispose(self: GlobalContextRef) {}
}

def create_context -> ContextRef {
    return ContextRef(LLVMPY_ContextCreate());
}

def get_global_context -> GlobalContextRef {
    return GlobalContextRef(LLVMPY_GetGlobalContext());
}
