"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.diagnostics {
    E1001,
    E1002,
    E1003,
    E1004,
    E1010,
    E1011,
    E1020,
    E1021,
    E1022,
    E1060,
    E1061,
    E1090,
    E1091,
    E1092,
    E1093,
    E1094,
    E1095
}

"""Type checker pass for JacLang."""
class TypeCheckPass(UniPass) {
    def before_pass(self: TypeCheckPass) -> None;
    def _insert_builtin_symbols(self: TypeCheckPass) -> None;
    def enter_ability(self: TypeCheckPass, nd: uni.Ability) -> None;
    def exit_ability(self: TypeCheckPass, nd: uni.Ability) -> None;
    def exit_type_alias(self: TypeCheckPass, nd: uni.TypeAlias) -> None;
    def exit_archetype(self: TypeCheckPass, nd: uni.Archetype) -> None;
    def exit_enum(self: TypeCheckPass, nd: uni.Enum) -> None;
    def exit_import(self: TypeCheckPass, nd: uni.Import) -> None;
    def exit_assignment(self: TypeCheckPass, nd: uni.Assignment) -> None;
    def exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None;
    def exit_binary_expr(self: TypeCheckPass, nd: uni.BinaryExpr) -> None;
    def enter_bool_expr(self: TypeCheckPass, nd: uni.BoolExpr) -> None;
    def exit_bool_expr(self: TypeCheckPass, nd: uni.BoolExpr) -> None;
    def exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None;
    def exit_filter_compr(self: TypeCheckPass, nd: uni.FilterCompr) -> None;
    def exit_return_stmt(self: TypeCheckPass, nd: uni.ReturnStmt) -> None;
    def exit_formatted_value(self: TypeCheckPass, nd: uni.FormattedValue) -> None;
    def exit_edge_ref_trailer(self: TypeCheckPass, nd: uni.EdgeRefTrailer) -> None;
    def exit_special_var_ref(self: TypeCheckPass, nd: uni.SpecialVarRef) -> None;
    def exit_name(self: TypeCheckPass, nd: uni.Name) -> None;
    def enter_if_stmt(self: TypeCheckPass, nd: uni.IfStmt) -> None;
    def exit_if_stmt(self: TypeCheckPass, nd: uni.IfStmt) -> None;
    def exit_param_var(self: TypeCheckPass, nd: uni.ParamVar) -> None;
    def exit_has_var(self: TypeCheckPass, nd: uni.HasVar) -> None;
    def exit_in_for_stmt(self: TypeCheckPass, nd: uni.InForStmt) -> None;
    def exit_raise_stmt(self: TypeCheckPass, nd: uni.RaiseStmt) -> None;
    def enter_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None;
    def exit_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None;
    def exit_while_stmt(self: TypeCheckPass, nd: uni.WhileStmt) -> None;
    def exit_assert_stmt(self: TypeCheckPass, nd: uni.AssertStmt) -> None;
    def exit_yield_expr(self: TypeCheckPass, nd: uni.YieldExpr) -> None;
    def exit_delete_stmt(self: TypeCheckPass, nd: uni.DeleteStmt) -> None;
    def exit_visit_stmt(self: TypeCheckPass, nd: uni.VisitStmt) -> None;
    def exit_report_stmt(self: TypeCheckPass, nd: uni.ReportStmt) -> None;
    def exit_impl_def(self: TypeCheckPass, nd: uni.ImplDef) -> None;
    def exit_sub_tag(self: TypeCheckPass, nd: uni.SubTag[uni.T]) -> None;
    def _eval_unpacking_names(self: TypeCheckPass, container: uni.Expr) -> None;
    def _body_always_returns(
        self: TypeCheckPass, body: list[uni.CodeBlockStmt]
    ) -> bool;
}
