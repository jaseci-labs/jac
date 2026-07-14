import from typing { TypeAlias }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { OwnershipKind, SymbolStorage, is_borrow_kind }
import from jaclang.jac0core.passes.transform { Transform }

glob SymId: TypeAlias = int;

obj RcElisionProofPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _cfg_owner(sub: uni.UniNode) -> (uni.UniCFGNode | None);
    def _is_def_name(nm: uni.Name) -> bool;
    def _is_alias_value(nm: uni.Name) -> bool;
    def _move_candidate_source(nd: uni.Assignment) -> (uni.Name | None);
    def _solve_liveness(
        cfg_nodes: list[uni.UniCFGNode], tracked: set[SymId]
    ) -> dict[int, set[SymId]];
}
