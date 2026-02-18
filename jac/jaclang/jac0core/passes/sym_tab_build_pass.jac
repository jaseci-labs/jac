"""Symbol Table Construction Pass for the Jac compiler.

This pass builds the hierarchical symbol table structure for the entire program by:

1. Creating symbol tables for each scope in the program (modules, archetypes, abilities, blocks)
2. Establishing parent-child relationships between nested scopes
3. Registering symbols for various language constructs:
   - Global variables and imports
   - Archetypes (objects, nodes, edges, walkers) and their members
   - Abilities (methods and functions) and their parameters
   - Enums and their values
   - Local variables in various block scopes

4. Adding special symbols like 'self' and 'super' in appropriate contexts
5. Maintaining scope boundaries for proper symbol resolution

The symbol table is a fundamental data structure that enables name resolution,
type checking, and semantic analysis throughout the compilation process.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolAccess, Tokens }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.unitree { UniScopeNode }
"""Jac Symbol table build pass."""
class SymTabBuildPass(UniPass) {
    """Before pass."""
    def before_pass(self: SymTabBuildPass) -> None;

    """Push scope."""
    def push_scope_and_link(self: SymTabBuildPass, key_node: uni.UniScopeNode) -> None;

    """Pop scope."""
    def pop_scope(self: SymTabBuildPass) -> UniScopeNode;

    """Return current scope."""
    @property
    def cur_scope(self: SymTabBuildPass) -> UniScopeNode;

    """Find scope node of a given node."""
    def find_python_scope_node_of(
        self: SymTabBuildPass, nd: uni.UniNode
    ) -> (UniScopeNode | None);

    """Check if a symbol's declaration has an explicit type annotation."""
    static def _outer_has_type_annotation(sym: uni.Symbol) -> bool {
        decl = sym.decl;
        if (decl is None) {
            return False;
        }
        name_of = decl?.name_of;
        if (name_of is None) {
            return False;
        }
        parent = name_of?.parent;
        return (
            (isinstance(parent, uni.Assignment) and (parent.type_tag is not None))
            or isinstance(name_of, (uni.HasVar, uni.ParamVar))
        );
    }

    """Create symbols for Name nodes in a module path."""
    def _bind_import_path_symbols(
        self: SymTabBuildPass, module_path: uni.ModulePath
    ) -> None;

    def enter_module(self: SymTabBuildPass, nd: uni.Module) -> None;
    def exit_module(self: SymTabBuildPass, nd: uni.Module) -> None;
    def enter_type_alias(self: SymTabBuildPass, nd: uni.TypeAlias) -> None;
    def exit_type_alias(self: SymTabBuildPass, nd: uni.TypeAlias) -> None;
    def enter_type_param(self: SymTabBuildPass, nd: uni.TypeParam) -> None;
    def exit_global_vars(self: SymTabBuildPass, nd: uni.GlobalVars) -> None;
    def exit_assignment(self: SymTabBuildPass, nd: uni.Assignment) -> None;
    """Handle walrus operator (:=) assignments."""
    def exit_binary_expr(self: SymTabBuildPass, nd: uni.BinaryExpr) -> None;

    def enter_test(self: SymTabBuildPass, nd: uni.Test) -> None;
    def exit_test(self: SymTabBuildPass, nd: uni.Test) -> None;
    def _exit_import_absorb(self: SymTabBuildPass, nd: uni.Import) -> None;
    def exit_import(self: SymTabBuildPass, nd: uni.Import) -> None;
    def exit_module_path(self: SymTabBuildPass, nd: uni.ModulePath) -> None;
    def exit_module_item(self: SymTabBuildPass, nd: uni.ModuleItem) -> None;
    def enter_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None;
    def exit_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None;
    def enter_ability(self: SymTabBuildPass, nd: uni.Ability) -> None;
    def exit_ability(self: SymTabBuildPass, nd: uni.Ability) -> None;
    def enter_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None;
    def exit_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None;
    def enter_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None;
    def exit_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None;
    def enter_enum(self: SymTabBuildPass, nd: uni.Enum) -> None;
    def enter_has_var(self: SymTabBuildPass, nd: uni.HasVar) -> None;
    def enter_param_var(self: SymTabBuildPass, nd: uni.ParamVar) -> None;
    """Handle attribute access for self member assignments."""
    def exit_atom_trailer(self: SymTabBuildPass, nd: uni.AtomTrailer) -> None;

    """Check if the node represents a simple `self.attr = value` assignment."""
    def _is_self_member_assignment(self: SymTabBuildPass, nd: uni.AtomTrailer) -> bool;

    def exit_enum(self: SymTabBuildPass, nd: uni.Enum) -> None;
    def enter_typed_ctx_block(self: SymTabBuildPass, nd: uni.TypedCtxBlock) -> None;
    def exit_typed_ctx_block(self: SymTabBuildPass, nd: uni.TypedCtxBlock) -> None;
    def enter_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None;
    def exit_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None;
    def enter_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None;
    def exit_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None;
    def enter_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None;
    def exit_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None;
    def enter_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None;
    def exit_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None;
    def enter_except(self: SymTabBuildPass, nd: uni.Except) -> None;
    def exit_except(self: SymTabBuildPass, nd: uni.Except) -> None;
    def enter_finally_stmt(self: SymTabBuildPass, nd: uni.FinallyStmt) -> None;
    def exit_finally_stmt(self: SymTabBuildPass, nd: uni.FinallyStmt) -> None;
    def enter_iter_for_stmt(self: SymTabBuildPass, nd: uni.IterForStmt) -> None;
    def exit_iter_for_stmt(self: SymTabBuildPass, nd: uni.IterForStmt) -> None;
    """Recursively define symbols in unpacking expressions."""
    def _def_insert_unpacking(
        self: SymTabBuildPass, nd: uni.Expr, sym_tab: UniScopeNode
    ) -> None;

    def enter_in_for_stmt(self: SymTabBuildPass, nd: uni.InForStmt) -> None;
    def exit_in_for_stmt(self: SymTabBuildPass, nd: uni.InForStmt) -> None;
    def enter_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None;
    def exit_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None;
    def enter_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None;
    def exit_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None;
    def exit_expr_as_item(self: SymTabBuildPass, nd: uni.ExprAsItem) -> None;
    def enter_lambda_expr(self: SymTabBuildPass, nd: uni.LambdaExpr) -> None;
    def exit_lambda_expr(self: SymTabBuildPass, nd: uni.LambdaExpr) -> None;
    def enter_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None;
    def exit_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None;
    def enter_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None;
    def exit_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None;
    def enter_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None;
    def exit_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None;
    def enter_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None;
    def exit_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None;
    def enter_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None;
    def exit_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None;
}
