import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.unitree { Symbol, UniScopeNode }
import from jaclang.jac0core.passes.sym_tab_build_pass {
    bind_assignment_targets,
    bind_global_stmt
}
import from jaclang.jac0core.diagnostics {
    E2009,
    W2010,
    E2011,
    E2012,
    W2013,
    E2016,
    E2017,
    E2026,
    W2080
}

class DeclImplMatchPass(Transform[uni.Module, uni.Module]) {
    has _e2026_reported: set[int];

    def transform(self: DeclImplMatchPass, ir_in: uni.Module) -> uni.Module;
    def defn_lookup(self: DeclImplMatchPass, lookup: Symbol) -> (uni.NameAtom | None);
    def _find_archetype_defn(
        self: DeclImplMatchPass, lookup: Symbol
    ) -> (uni.NameAtom | None);

    def connect_impls(
        self: DeclImplMatchPass,
        source_sym_tab: UniScopeNode,
        target_sym_tab: UniScopeNode
    ) -> None;

    def _connect_one_impl(
        self: DeclImplMatchPass,
        impl_node: uni.ImplDef,
        sym_name: str,
        target_sym_tab: UniScopeNode
    ) -> None;

    def _report_bare_redecls(self: DeclImplMatchPass, sym_tab: UniScopeNode) -> None;
    def validate_params_match(
        self: DeclImplMatchPass,
        impl_node: uni.ImplDef,
        sym_name: str,
        valid_decl: uni.AstSymbolNode
    ) -> None;

    def _resolve_symbols_in_subtree(
        self: DeclImplMatchPass, root_node: uni.UniNode
    ) -> None;

    def _populate_self_member_symbols(
        self: DeclImplMatchPass, impl_def: uni.ImplDef, archetype: uni.Archetype
    ) -> None;

    def _populate_inline_init_symbols(
        self: DeclImplMatchPass, archetype: uni.Archetype
    ) -> None;
}
