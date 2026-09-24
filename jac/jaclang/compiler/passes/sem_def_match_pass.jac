walker SemDefMatchPass {
    has ctx: CompileContext,
        module: Module;

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def resolve_sem_target(
        semdef: SemDef, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;
}
