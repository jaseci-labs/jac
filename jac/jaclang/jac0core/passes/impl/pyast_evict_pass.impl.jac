impl PyAstEvictPass.transform(self: PyAstEvictPass, ir_in: uni.Module) -> uni.Module {
    if os.environ.get("JAC_NO_PYAST_EVICT") {
        return ir_in;
    }
    compiler = self.prog._get_compiler();
    evict_all = bool(os.environ.get("JAC_PYAST_EVICT_ALL"));
    if (not evict_all) and (self.prog is not compiler.internal_program) {
        return ir_in;
    }

    for nd in ir_in.flatten() {
        if (nd._gen is not None and nd._gen.py_ast) {
            nd._gen.py_ast = [];
        }
    }
    return ir_in;
}
