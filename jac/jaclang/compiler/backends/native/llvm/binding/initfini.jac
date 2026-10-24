"""
    Initialize the LLVM core (deprecated).

    This function is deprecated and will raise an error when called.
    LLVM initialization is now handled automatically and no longer
    requires explicit initialization calls.

    Raises:
        RuntimeError: Always raised as this function is no longer needed.
    """
def initialize -> object {
    raise RuntimeError(
        "jaclang.compiler.backends.native.llvm.binding.initialize() is deprecated and will be removed. "
        "LLVM initialization is now handled automatically. "
        "Please remove calls to this function from your code and check for "
        "other behavioral changes that may have occurred due to LLVM updates."
    );
}

"""
    Initialize all targets. Necessary before targets can be looked up
    via the :class:`Target` class.
    """
def initialize_all_targets -> object {
    ffi.lib.LLVMPY_InitializeAllTargetInfos();
    ffi.lib.LLVMPY_InitializeAllTargets();
    ffi.lib.LLVMPY_InitializeAllTargetMCs();
}

"""
    Initialize all code generators. Necessary before generating
    any assembly or machine code via the :meth:`TargetMachine.emit_object`
    and :meth:`TargetMachine.emit_assembly` methods.
    """
def initialize_all_asmprinters -> object {
    ffi.lib.LLVMPY_InitializeAllAsmPrinters();
}

"""
    Initialize all assembly parsers. Necessary before emitting an object
    from a module that carries `module asm`, for any target other than the
    host -- the streamer hands inline assembly to the target's parser, and
    LLVM aborts the process when none is registered.
    """
def initialize_all_asmparsers -> object {
    ffi.lib.LLVMPY_InitializeAllAsmParsers();
}

"""
    Initialize the native (host) target.  Necessary before doing any
    code generation.
    """
def initialize_native_target -> object {
    ffi.lib.LLVMPY_InitializeNativeTarget();
}

"""
    Initialize the native ASM printer.
    """
def initialize_native_asmprinter -> object {
    ffi.lib.LLVMPY_InitializeNativeAsmPrinter();
}

"""
    Initialize the native ASM parser.
    """
def initialize_native_asmparser -> object {
    ffi.lib.LLVMPY_InitializeNativeAsmParser();
}

def shutdown -> object {
    ffi.lib.LLVMPY_Shutdown();
}
