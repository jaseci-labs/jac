"""JIT compile LLVM IR to native machine code using llvmlite.

Takes the LLVM IR module from NaIRGenPass and compiles it to
executable native code via MCJIT. Function addresses can then
be called via ctypes.
"""

import llvmlite.binding as llvm;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes.uni_pass { UniPass }

"""JIT compile LLVM IR module to native machine code."""
obj NativeCompilePass(UniPass) {
    def init(
        ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
    ) -> None;

    def before_pass -> None;
}
