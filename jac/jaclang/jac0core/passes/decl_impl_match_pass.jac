"""Declaration-Implementation Matching Pass for the Jac compiler.

This pass connects declarations (Decls) of Archetypes and Abilities with their
separate
implementations (Defs) in the AST. It:

1. Establishes links between declarations in the main module and their
implementations
   in separate .impl.jac files
2. Validates parameter matching between ability declarations and their
implementations
3. Ensures proper inheritance of symbol tables between declarations and
implementations

This pass is essential for Jac's separation of interface and implementation,
allowing
developers to define archetype and ability interfaces in one file while
implementing
their behavior in separate files.
"""
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

"""Decls and Def matching pass."""
class DeclImplMatchPass(Transform[uni.Module, uni.Module]) {
    has _e2026_reported: set[int];

    """Connect Decls and Defs."""
    def transform(self: DeclImplMatchPass, ir_in: uni.Module) -> uni.Module;

    """Lookup a definition in a symbol table."""
    def defn_lookup(self: DeclImplMatchPass, lookup: Symbol) -> (uni.NameAtom | None);

    """Find the archetype definition from a symbol's definitions.

        When a class is used as a base class, its symbol may have multiple
        definitions - the actual Archetype and Name references from inheritance.
        This method finds the actual Archetype definition.
        """
    def _find_archetype_defn(
        self: DeclImplMatchPass, lookup: Symbol
    ) -> (uni.NameAtom | None);

    """Connect implementations from source symbol table to declarations in
target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects
within the same module.
        When different, it connects implementations in one scope to
declarations in another.
        """
    def connect_impls(
        self: DeclImplMatchPass,
        source_sym_tab: UniScopeNode,
        target_sym_tab: UniScopeNode
    ) -> None;

    """Connect a single ImplDef to its declaration in target_sym_tab.

        Run once per ImplDef that defines a symbol: after annexes/variants are
        merged, several ImplDefs (a head impl plus an annex's) can share one
        symbol, and visiting each is what surfaces a duplicate implementation
        (E2017) -- the second to resolve a decl that is already bodied."""
    def _connect_one_impl(
        self: DeclImplMatchPass,
        impl_node: uni.ImplDef,
        sym_name: str,
        target_sym_tab: UniScopeNode
    ) -> None;

    """Detect bare re-declaring definitions (`def foo {...}` written instead of
    `impl foo {...}`) merged from annex files that shadow an unlinked stub."""
    def _report_bare_redecls(self: DeclImplMatchPass, sym_tab: UniScopeNode) -> None;

    """Validate if the parameters match."""
    def validate_params_match(
        self: DeclImplMatchPass,
        impl_node: uni.ImplDef,
        sym_name: str,
        valid_decl: uni.AstSymbolNode
    ) -> None;

    """Resolve unresolved Name and AtomTrailer symbols in a subtree."""
    def _resolve_symbols_in_subtree(
        self: DeclImplMatchPass, root_node: uni.UniNode
    ) -> None;

    """Populate self-member symbols from impl body to archetype's symbol table.

    When an impl file contains `self.x = value` assignments in a method, these
    define instance attributes on the archetype. Since SymTabBuildPass runs on
    impl files before they're connected to their declarations, it can't populate
    these symbols into the archetype. This method does that after connection."""
    def _populate_self_member_symbols(
        self: DeclImplMatchPass, impl_def: uni.ImplDef, archetype: uni.Archetype
    ) -> None;

    """Scan inline init/postinit bodies for annotated self-assignments on
    obj/node/edge/walker archetypes. Emits W2080 and registers the symbol
    so downstream type checking resolves correctly."""
    def _populate_inline_init_symbols(
        self: DeclImplMatchPass, archetype: uni.Archetype
    ) -> None;
}
