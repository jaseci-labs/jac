import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }

class PyAstEvictPass(Transform[uni.Module, uni.Module]) {
    def transform(self: PyAstEvictPass, ir_in: uni.Module) -> uni.Module;
}
