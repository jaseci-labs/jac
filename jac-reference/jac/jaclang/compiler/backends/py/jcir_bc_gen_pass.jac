walker JcirBytecodeGenPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def process_modules(root_module: Module) -> None;
    def transcribe_module(mod: Module) -> None;
}
