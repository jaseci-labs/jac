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
"""Decls and Def matching pass."""
class DeclImplMatchPass(Transform[(uni.Module, uni.Module)]) {
    """Connect Decls and Defs."""
    def transform(self: DeclImplMatchPass, ir_in: uni.Module) -> uni.Module;

    """Lookup a definition in a symbol table."""
    def defn_lookup(self: DeclImplMatchPass, lookup: Symbol) -> (uni.NameAtom | None);

    """Connect implementations from source symbol table to declarations in
target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects
within the same module.
        When different, it connects implementations from impl_mod to
declarations in the main module.
        """
    def connect_impls(
        self: DeclImplMatchPass,
        source_sym_tab: UniScopeNode,
        target_sym_tab: UniScopeNode
    ) -> None;

    """Validate if the parameters match."""
    def validate_params_match(
        self: DeclImplMatchPass, sym: Symbol, valid_decl: uni.AstSymbolNode
    ) -> None;

    """Re-resolve symbols in an impl body after symbol table synchronization.

        When impl files are compiled, they don't have access to the base
module's
        symbols (like 'self' or archetype members). After DeclImplMatchPass
links
        the impl to its declaration and synchronizes symbol tables, we need to
        re-traverse the impl body to resolve these symbols.
        """
    def _resolve_impl_body_symbols(
        self: DeclImplMatchPass, impl_def: uni.ImplDef
    ) -> None;
}
