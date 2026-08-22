import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { E5040, E5043 }

class JcirBytecodeGenPass(Transform) {
    def transform(self: JcirBytecodeGenPass, ir_in: Module) -> Module;
    def process_modules(self: JcirBytecodeGenPass, root_module: Module) -> None;
    def transcribe_module(self: JcirBytecodeGenPass, mod: Module) -> None;
}
