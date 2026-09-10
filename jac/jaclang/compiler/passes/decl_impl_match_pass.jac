import from jaclang.runtime.object_model { field }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AstImplNeedingNode,
    AstSymbolNode,
    AtomTrailer,
    FuncSignature,
    HasVar,
    ImplDef,
    Module,
    Name,
    NameAtom,
    ParamVar,
    SpecialVarRef,
    Symbol,
    UniNode,
    UniScopeNode,
    bind_assignment_targets,
    find_python_scope_node_of,
    is_identifier_slot
}
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.diagnostics {
    E2009,
    E2011,
    E2012,
    W2013,
    E2016,
    E2017,
    E2026,
    W2080
}

walker DeclImplMatchPass(Transform) {
    has _e2026_reported: set[int] = field(default_factory=`set);

    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def defn_lookup(lookup: Symbol) -> (NameAtom | None);
    def _find_archetype_defn(lookup: Symbol) -> (NameAtom | None);
    def connect_impls(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;

    def _connect_one_impl(
        impl_node: ImplDef, sym_name: str, target_sym_tab: UniScopeNode
    ) -> None;

    def _share_scope_names(impl_node: ImplDef, valid_decl: AstImplNeedingNode) -> None;
    def _report_bare_redecls(sym_tab: UniScopeNode) -> None;
    def validate_params_match(
        impl_node: ImplDef, sym_name: str, valid_decl: AstSymbolNode
    ) -> None;

    def _resolve_symbols_in_subtree(root_node: UniNode) -> None;
    def _populate_self_member_symbols(impl_def: ImplDef, archetype: Archetype) -> None;
    def _populate_inline_init_symbols(archetype: Archetype) -> None;
}
