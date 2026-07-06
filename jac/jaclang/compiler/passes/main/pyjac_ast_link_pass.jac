import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes { UniPass }

obj PyJacAstLinkPass(UniPass) {
    def link_jac_py_nodes(jac_node: uni.UniNode, py_nodes: list[ast3.AST]) -> None;
    def exit_module_path(nd: uni.ModulePath) -> None;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def exit_param_var(nd: uni.ParamVar) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_expr_as_item(nd: uni.ExprAsItem) -> None;
    def exit_global_stmt(nd: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(nd: uni.NonLocalStmt) -> None;
    def exit_k_w_pair(nd: uni.KWPair) -> None;
    def exit_atom_trailer(nd: uni.AtomTrailer) -> None;
}
