"""JIT compile LLVM IR to native machine code using llvmlite.

Takes the LLVM IR module from NaIRGenPass and compiles it to
executable native code via MCJIT. Function addresses can then
be called via ctypes.
"""

import llvmlite.binding as llvm;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { Transform }
import from jaclang.jac0core.diagnostics {
    E5020,
    W5021,
    W5022,
    W5023,
    E5024,
    E5025,
    E5026
}

"""JIT compile LLVM IR module to native machine code."""
obj NativeCompilePass(Transform) {
    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    # Link imported .na.jac modules at IR level (na↔na linking)
    def _compile_and_link_native_imports(
        module: uni.Module, main_mod: object, imports: list, target_machine: object
    ) -> None;
}
