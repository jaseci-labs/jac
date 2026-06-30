import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolAccess }
import from jaclang.jac0core.modresolver { find_jac_project_root }
import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E2034,
    W2034,
    E2035,
    W2035,
    E2037,
    W2037,
    E2038,
    W2038
}

obj AccessCheckPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None,
        _enforce: bool = False;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _read_enforce -> bool;
    def _check_use(use_node: uni.AstSymbolNode, sym: uni.Symbol) -> None;
    def _check_member(
        use_node: uni.AstSymbolNode, sym: uni.Symbol, owner: uni.Archetype
    ) -> None;

    def _emit_pair(
        warn: DiagnosticInfo, err: DiagnosticInfo, at_node: uni.UniNode, **kwargs: any
    ) -> None;

    def _declaring_archetype(sym: uni.Symbol) -> (uni.Archetype | None);
    def _base_archetype(expr: uni.UniNode) -> (uni.Archetype | None);
    def _is_subclass_of(child: uni.Archetype, ancestor: uni.Archetype) -> bool;
}
