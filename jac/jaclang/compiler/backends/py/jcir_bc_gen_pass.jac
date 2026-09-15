import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.context { CompileContext }

import from jaclang.compiler.frontend.diagnostics { E5040, E5043 }

walker JcirBytecodeGenPass {
    has ctx: CompileContext,
        module: Module;

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def process_modules(root_module: Module) -> None;
    def transcribe_module(mod: Module) -> None;
}
