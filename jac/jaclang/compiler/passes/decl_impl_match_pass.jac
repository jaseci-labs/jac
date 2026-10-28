walker DeclImplMatchPass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.SYM_OF, ),
        provides=(AnalysisFact.IMPL_OF, ),
        kernel_safe=True
    );

    has _e2026_reported: set[int] = set();

    def _run_impl(ir_in: Module) -> Module;
    def _report_unimplemented(ir_in: Module) -> None;
    def _impl_optional(ability: Ability, supplied: dict[str, set[str]]) -> bool;
    def _impl_block_members(ir_in: Module) -> dict[str, set[str]];
    can run_walk with Module entry;
    def defn_lookup(lookup: Symbol) -> (NameAtom | None);
    def _find_archetype_defn(lookup: Symbol) -> (NameAtom | None);
    def connect_impls(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;

    def _connect_one_impl(
        impl_node: ImplDef, sym_name: str, target_sym_tab: UniScopeNode
    ) -> None;

    def _report_bare_redecls(sym_tab: UniScopeNode) -> None;
    def validate_params_match(
        impl_node: ImplDef, sym_name: str, valid_decl: AstSymbolNode
    ) -> None;

    def _resolve_symbols_in_subtree(root_node: UniNode) -> None;
    def _populate_self_member_symbols(impl_def: ImplDef, archetype: Archetype) -> None;
    def _populate_inline_init_symbols(archetype: Archetype) -> None;
}
