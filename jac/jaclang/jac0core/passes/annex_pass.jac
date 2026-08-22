import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.passes.annex_weave { merge_annex_into }
import from jaclang.jac0core.passes.transform { Transform }

class JacAnnexPass(Transform) {
    def transform(self: JacAnnexPass, ir_in: Module) -> Module;
    static def _merge_annex(nd: Module, annex_mod: Module) -> None;
}
