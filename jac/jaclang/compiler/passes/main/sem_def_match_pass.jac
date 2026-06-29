import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.unitree { Symbol, UniScopeNode }

obj SemDefMatchPass(Transform[uni.Module, uni.Module]) {
    def transform(ir_in: uni.Module) -> uni.Module;
    def resolve_sem_target(
        semdef: uni.SemDef, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;
}
