"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }

"""Type checker pass for JacLang."""
obj TypeCheckPass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def before_pass -> None;
    def _add_diagnostic(<>node: uni.UniNode, message: str, warning: bool) -> None;
    def _insert_builtin_symbols -> None;
    def enter_ability(<>node: uni.Ability) -> None;
    def exit_ability(<>node: uni.Ability) -> None;
    def _traverse_impl_body(impl_def: uni.ImplDef) -> None;
    def exit_impl_def(<>node: uni.ImplDef) -> None;
    def exit_import(<>node: uni.Import) -> None;
    def exit_assignment(<>node: uni.Assignment) -> None;
    def exit_atom_trailer(<>node: uni.AtomTrailer) -> None;
    def exit_binary_expr(<>node: uni.BinaryExpr) -> None;
    def exit_func_call(<>node: uni.FuncCall) -> None;
    def exit_filter_compr(<>node: uni.FilterCompr) -> None;
    def exit_return_stmt(<>node: uni.ReturnStmt) -> None;
    def exit_formatted_value(<>node: uni.FormattedValue) -> None;
    def exit_edge_ref_trailer(<>node: uni.EdgeRefTrailer) -> None;
    def exit_special_var_ref(<>node: uni.SpecialVarRef) -> None;
    def exit_name(<>node: uni.Name) -> None;
}
