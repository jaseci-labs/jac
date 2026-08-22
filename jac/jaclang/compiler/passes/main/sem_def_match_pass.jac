import from jaclang.jac0core.unitree { Module, SemDef, Symbol, UniScopeNode }
import from jaclang.jac0core.passes.transform { Transform }

obj SemDefMatchPass(Transform) {
    def transform(ir_in: Module) -> Module;
    def resolve_sem_target(
        semdef: SemDef, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;
}
