import from ctypes { c_uint }
import from jaclang.compiler.passes.native.llvm.binding { ffi }


def initialize() -> object {
    raise RuntimeError(
        "jaclang.compiler.passes.native.llvm.binding.initialize() is deprecated and will be removed. "
        "other behavioral changes that may have occurred due to LLVM updates."
    );
}

def initialize_all_targets() -> object {
    ffi.lib.LLVMPY_InitializeAllTargetInfos();
    ffi.lib.LLVMPY_InitializeAllTargets();
    ffi.lib.LLVMPY_InitializeAllTargetMCs();
}

def initialize_all_asmprinters() -> object {
    ffi.lib.LLVMPY_InitializeAllAsmPrinters();
}

def initialize_native_target() -> object {
    ffi.lib.LLVMPY_InitializeNativeTarget();
}

def initialize_native_asmprinter() -> object {
    ffi.lib.LLVMPY_InitializeNativeAsmPrinter();
}

def initialize_native_asmparser() -> object {
    ffi.lib.LLVMPY_InitializeNativeAsmParser();
}

def shutdown() -> object {
    ffi.lib.LLVMPY_Shutdown();
}

with entry {
    ffi.lib.LLVMPY_GetVersionInfo.restype = c_uint;
}

def _version_info() -> object {
    v = [];
    x = ffi.lib.LLVMPY_GetVersionInfo();
    while x {
        v.append((x & 255));
        x >>= 8;
    }
    return `tuple(reversed(v));
}

with entry {
    llvm_version_info = _version_info();
}
