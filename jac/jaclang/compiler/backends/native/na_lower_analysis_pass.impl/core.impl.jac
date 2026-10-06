impl take_native_lowering(
    module: uni.Module, prog: JacProgram, ctx: CompileContext
) -> NativeLowering {
    found = _READY.pop(id(module), None);
    if found is None or found.module is not module {
        found = NativeLowering(module=module, prog=prog, ctx=ctx);
    }
    found.ctx = ctx;
    return found;
}

impl NaLowerAnalysisPass._run_impl(ir_in: uni.Module) -> uni.Module {
    _READY.clear();
    _READY[id(ir_in)] = NativeLowering(module=ir_in, prog=self.prog, ctx=self.ctx);
    return ir_in;
}

impl NaLowerAnalysisPass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
}
