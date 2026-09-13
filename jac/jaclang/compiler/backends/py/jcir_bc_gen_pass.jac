import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.frontend.diagnostics { E5040, E5043 }

walker JcirBytecodeGenPass(Transform) {
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def process_modules(root_module: Module) -> None;
    def transcribe_module(mod: Module) -> None;
}
