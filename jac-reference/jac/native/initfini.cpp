#include "llvm-c/Core.h"
#include "llvm-c/Target.h"

#include "core.h"
#include "llvm/Config/llvm-config.h"

extern "C" {

// Pass registry and initialization APIs support dropped
// https://reviews.llvm.org/D145043

API_EXPORT(void)
LLVMPY_Shutdown() { LLVMShutdown(); }

// Target Initialization
#define INIT(F)                                                                \
    API_EXPORT(void) LLVMPY_Initialize##F() { LLVMInitialize##F(); }

// NOTE: it is important that we don't export functions which we don't use,
// especially those which may pull in large amounts of additional code or data.

INIT(AllTargetInfos)
INIT(AllTargets)
INIT(AllTargetMCs)
INIT(AllAsmPrinters)
// AllAsmParsers, not just NativeAsmParser: the aarch64 outline-atomics helpers
// are emitted as `module asm`, and assembling module asm needs an asm parser
// for the TARGET. A cross build (x86_64 host, `--target aarch64-...`) has no
// use for the host's parser, and LLVM answers a missing one with
// report_fatal_error -- an abort, not a catchable failure.
INIT(AllAsmParsers)
INIT(NativeTarget)
INIT(NativeAsmParser)
INIT(NativeAsmPrinter)
// INIT(NativeDisassembler)

#undef INIT

API_EXPORT(unsigned int)
LLVMPY_GetVersionInfo() {
    unsigned int verinfo = 0;
    verinfo += LLVM_VERSION_MAJOR << 16;
    verinfo += LLVM_VERSION_MINOR << 8;
#ifdef LLVM_VERSION_PATCH
    /* Not available under Windows... */
    verinfo += LLVM_VERSION_PATCH << 0;
#endif
    return verinfo;
}

} // end extern "C"
