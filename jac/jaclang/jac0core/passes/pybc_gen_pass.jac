import ast as ast3;
import marshal;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { E5040, E5043 }

class PyBytecodeGenPass(Transform[uni.Module, uni.Module]) {
    def transform(self: PyBytecodeGenPass, ir_in: uni.Module) -> uni.Module;
    def process_modules(self: PyBytecodeGenPass, root_module: uni.Module) -> None;
    def compile_module_to_bytecode(self: PyBytecodeGenPass, mod: uni.Module) -> None;
}
