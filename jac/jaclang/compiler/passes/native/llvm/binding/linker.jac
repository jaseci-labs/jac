import from ctypes { c_int, c_char_p, POINTER }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
def link_modules(dst: Any, src: Any) -> object {
    with ffi.OutputString() as outerr {
        err = ffi.lib.LLVMPY_LinkModules(dst, src, outerr);
        src.detach();
        if err {
            raise RuntimeError(str(outerr));
        }
    }
}
with entry {
    ffi.lib.LLVMPY_LinkModules.argtypes = [
        ffi.LLVMModuleRef,
        ffi.LLVMModuleRef,
        POINTER(c_char_p)
    ];
    ffi.lib.LLVMPY_LinkModules.restype = c_int;
}

