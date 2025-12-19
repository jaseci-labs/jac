"""Definition-Use Analysis Pass for the Jac compiler.

This pass performs comprehensive symbol resolution by:
1. Populating symbol tables with additional symbols from various AST constructs:
   - Variable assignments and declarations
   - Function/ability parameters
   - Archetype reference chains
   - Loop variables and comprehension targets
   - With-statement variables

2. Establishing bidirectional links between:
   - Symbol definitions in the symbol table
   - Symbol uses throughout the AST

3. Handling special cases:
   - Inheriting symbol tables from base classes for archetypes
   - Setting appropriate context for symbols in different operations (e.g., delete statements)
   - Marking walker-specific statements (visit, ignore, disengage) when in walker context

This pass is crucial for type checking, access control validation, and code generation as it
creates the complete symbol resolution map for the program.
"""
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes { UniPass }
"""Jac Ast build pass."""
class DefUsePass(UniPass) {
    def enter_archetype(self: DefUsePass, node: uni.Archetype) -> None;
    def enter_type_ref(self: DefUsePass, node: uni.TypeRef) -> None;
    def enter_param_var(self: DefUsePass, node: uni.ParamVar) -> None;
    def enter_has_var(self: DefUsePass, node: uni.HasVar) -> None;
    def enter_assignment(self: DefUsePass, node: uni.Assignment) -> None;
    def enter_inner_compr(self: DefUsePass, node: uni.InnerCompr) -> None;
    def enter_atom_trailer(self: DefUsePass, node: uni.AtomTrailer) -> None;
    def enter_special_var_ref(self: DefUsePass, node: uni.SpecialVarRef) -> None;
    def enter_float(self: DefUsePass, node: uni.Float) -> None;
    def enter_int(self: DefUsePass, node: uni.Int) -> None;
    def enter_string(self: DefUsePass, node: uni.String) -> None;
    def enter_bool(self: DefUsePass, node: uni.Bool) -> None;
    def enter_builtin_type(self: DefUsePass, node: uni.BuiltinType) -> None;
    def enter_name(self: DefUsePass, node: uni.Name) -> None;
    def enter_in_for_stmt(self: DefUsePass, node: uni.InForStmt) -> None;
    def enter_expr_as_item(self: DefUsePass, node: uni.ExprAsItem) -> None;
}
