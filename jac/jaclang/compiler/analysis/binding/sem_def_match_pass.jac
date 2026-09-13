import from jaclang.compiler.ir.schema { Module, SemDef, Symbol, UniScopeNode }
import from jaclang.compiler.pipeline.pass_base { Transform }

walker SemDefMatchPass(Transform) {
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def resolve_sem_target(
        semdef: SemDef, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;
}
