"""Python-Jac AST Linking Pass for the Jac compiler.\n\nThis pass establishes bidirectional links between Python AST nodes and their corresponding\nJac AST nodes by:\n\n1. Creating connections where multiple Jac nodes map to a single Python node\n2. Handling special cases like abilities/functions where the structure differs between languages\n3. Ensuring proper name resolution across the AST boundary\n4. Maintaining parameter correspondence between declarations and implementations\n5. Supporting complex language constructs like archetypes, enums, and abilities\n\nThese links are essential for error reporting, debugging, and maintaining semantic\nrelationships between the two AST representations throughout the compilation process.\n"""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }
"""Link jac ast to python ast nodes."""
class PyJacAstLinkPass(UniPass) {
    def link_jac_py_nodes(
        self: PyJacAstLinkPass, jac_node: uni.UniNode, py_nodes: list[ast3.AST]
    ) -> None;

    def exit_module_path(self: PyJacAstLinkPass, <>node: uni.ModulePath) -> None;
    def exit_archetype(self: PyJacAstLinkPass, <>node: uni.Archetype) -> None;
    def exit_enum(self: PyJacAstLinkPass, <>node: uni.Enum) -> None;
    def exit_ability(self: PyJacAstLinkPass, <>node: uni.Ability) -> None;
    def exit_impl_def(self: PyJacAstLinkPass, <>node: uni.ImplDef) -> None;
    def exit_param_var(self: PyJacAstLinkPass, <>node: uni.ParamVar) -> None;
    def exit_except(self: PyJacAstLinkPass, <>node: uni.Except) -> None;
    def exit_expr_as_item(self: PyJacAstLinkPass, <>node: uni.ExprAsItem) -> None;
    def exit_global_stmt(self: PyJacAstLinkPass, <>node: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(self: PyJacAstLinkPass, <>node: uni.NonLocalStmt) -> None;
    def exit_k_w_pair(self: PyJacAstLinkPass, <>node: uni.KWPair) -> None;
    def exit_atom_trailer(self: PyJacAstLinkPass, <>node: uni.AtomTrailer) -> None;
}
