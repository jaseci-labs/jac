import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.project.diagnostics { E5040, E5043 }

walker JcirBytecodeGenPass(Transform) {
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def process_modules(root_module: Module) -> None;
    def transcribe_module(mod: Module) -> None;
}
