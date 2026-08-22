import from jaclang.jac0core.unitree {
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
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics {
    E2009,
    E2011,
    E2012,
    W2013,
    E2016,
    E2017,
    E2026,
    W2080
}

class DeclImplMatchPass(Transform) {
    has _e2026_reported: set[int];

    def transform(self: DeclImplMatchPass, ir_in: Module) -> Module;
    def defn_lookup(self: DeclImplMatchPass, lookup: Symbol) -> (NameAtom | None);
    def _find_archetype_defn(
        self: DeclImplMatchPass, lookup: Symbol
    ) -> (NameAtom | None);

    def connect_impls(
        self: DeclImplMatchPass,
        source_sym_tab: UniScopeNode,
        target_sym_tab: UniScopeNode
    ) -> None;

    def _connect_one_impl(
        self: DeclImplMatchPass,
        impl_node: ImplDef,
        sym_name: str,
        target_sym_tab: UniScopeNode
    ) -> None;

    def _report_bare_redecls(self: DeclImplMatchPass, sym_tab: UniScopeNode) -> None;
    def validate_params_match(
        self: DeclImplMatchPass,
        impl_node: ImplDef,
        sym_name: str,
        valid_decl: AstSymbolNode
    ) -> None;

    def _resolve_symbols_in_subtree(
        self: DeclImplMatchPass, root_node: UniNode
    ) -> None;

    def _populate_self_member_symbols(
        self: DeclImplMatchPass, impl_def: ImplDef, archetype: Archetype
    ) -> None;

    def _populate_inline_init_symbols(
        self: DeclImplMatchPass, archetype: Archetype
    ) -> None;
}
