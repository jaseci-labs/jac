impl PyAstEvictPass.transform(self: PyAstEvictPass, ir_in: uni.Module) -> uni.Module {
    ir_in.evict_py_ast();
    return ir_in;
}
