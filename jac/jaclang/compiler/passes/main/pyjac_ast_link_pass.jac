"""
Python-Jac AST Linking Pass for the Jac compiler.

This pass establishes bidirectional links between Python AST nodes and their corresponding
Jac AST nodes by:

1. Creating connections where multiple Jac nodes map to a single Python node
2. Handling special cases like abilities/functions where the structure differs between languages
3. Ensuring proper name resolution across the AST boundary
4. Maintaining parameter correspondence between declarations and implementations
5. Supporting complex language constructs like archetypes, enums, and abilities

These links are essential for error reporting, debugging, and maintaining semantic
relationships between the two AST representations throughout the compilation process.
"""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { CodeContext }
import from jaclang.pycore.passes { UniPass }
"""Link jac ast to python ast nodes."""
obj PyJacAstLinkPass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def link_jac_py_nodes(jac_node: uni.UniNode, py_nodes: list[ast3.AST]) -> None;
    def exit_module_path(<>node: uni.ModulePath) -> None;
    def exit_archetype(<>node: uni.Archetype) -> None;
    def exit_enum(<>node: uni.Enum) -> None;
    def exit_ability(<>node: uni.Ability) -> None;
    def exit_impl_def(<>node: uni.ImplDef) -> None;
    def exit_param_var(<>node: uni.ParamVar) -> None;
    def exit_except(<>node: uni.Except) -> None;
    def exit_expr_as_item(<>node: uni.ExprAsItem) -> None;
    def exit_global_stmt(<>node: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None;
    def exit_k_w_pair(<>node: uni.KWPair) -> None;
    def exit_atom_trailer(<>node: uni.AtomTrailer) -> None;
}
