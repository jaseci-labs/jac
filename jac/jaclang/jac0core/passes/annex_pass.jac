import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.bccache { discover_annex_files, discover_variant_files }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

class JacAnnexPass(Transform[uni.Module, uni.Module]) {
    def transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module;
    def _load_annexes(
        self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
    ) -> None;

    def _merge_annex_group(
        self: JacAnnexPass,
        nd: uni.Module,
        base_path: str,
        ctx_path: str,
        seen: set[str]
    ) -> None;

    def _merge_annex(
        self: JacAnnexPass, nd: uni.Module, path: str, ctx_path: str, seen: set[str]
    ) -> None;
}
