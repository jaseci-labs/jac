"""Register every target LLVM was built with, before a Target lookup."""
def initialize_all_targets {
    LLVMPY_InitializeAllTargetInfos();
    LLVMPY_InitializeAllTargets();
    LLVMPY_InitializeAllTargetMCs();
}

"""Register every code generator, before emitting an object or assembly."""
def initialize_all_asmprinters {
    LLVMPY_InitializeAllAsmPrinters();
}

"""Register every assembly parser: emitting an object from a module with
`module asm` hands it to its target's parser, and LLVM aborts when none is
registered."""
def initialize_all_asmparsers {
    LLVMPY_InitializeAllAsmParsers();
}

def initialize_native_target {
    LLVMPY_InitializeNativeTarget();
}

def initialize_native_asmprinter {
    LLVMPY_InitializeNativeAsmPrinter();
}

def initialize_native_asmparser {
    LLVMPY_InitializeNativeAsmParser();
}
