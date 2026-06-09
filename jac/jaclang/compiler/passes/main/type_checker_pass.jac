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
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E1001,
    E1002,
    E1003,
    E1004,
    E1005,
    E1010,
    E1011,
    E1020,
    E1021,
    E1022,
    E1042,
    E1060,
    E1061,
    E1090,
    E1091,
    E1092,
    E1093,
    E1094,
    E1095,
    E1112,
    E1113,
    E1116,
    E1117,
    W1036,
    W1037,
    W1052,
    W2014,
    E2015
}

"""Type checker pass for JacLang."""
class TypeCheckPass(UniPass) {
    # When True (TypeInferencePass), non-ICE diagnostics are gated; direct
    # TypeCheckPass invocations always emit in full. See before_pass/emit.
    static has inference_only: bool = False;

    def before_pass(self: TypeCheckPass) -> None;
    def after_pass(self: TypeCheckPass) -> None;
    """Diagnostic gate for the typed-tree contract: inference always runs,
    but TYPE diagnostics are only surfaced in full-diagnostic mode (`jac
    check` / options.type_check, or native-context modules per #6049).
    ICE-category diagnostics are never suppressed. See before_pass."""
    def emit(
        self: TypeCheckPass,
        diag: DiagnosticInfo,
        node_override: (uni.UniNode | None) = None,
        related: (list[tuple[str, uni.UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;

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
    def exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None;
    def exit_jsx_element(self: TypeCheckPass, nd: uni.JsxElement) -> None;
    def exit_filter_compr(self: TypeCheckPass, nd: uni.FilterCompr) -> None;
    def exit_return_stmt(self: TypeCheckPass, nd: uni.ReturnStmt) -> None;
    def exit_formatted_value(self: TypeCheckPass, nd: uni.FormattedValue) -> None;
    def exit_edge_ref_trailer(self: TypeCheckPass, nd: uni.EdgeRefTrailer) -> None;
    def exit_special_var_ref(self: TypeCheckPass, nd: uni.SpecialVarRef) -> None;
    def exit_name(self: TypeCheckPass, nd: uni.Name) -> None;
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

    def _check_bare_generic(
        self: TypeCheckPass, ann_node: uni.UniNode, ty: object
    ) -> None;

    def _check_explicit_any(self: TypeCheckPass, ann_node: uni.UniNode) -> None;
    def _check_walker_reports_shape(
        self: TypeCheckPass, nd: uni.HasVar, declared_type: object
    ) -> None;

    def _enclosing_walker_report_elem_type(
        self: TypeCheckPass, nd: uni.UniNode
    ) -> object;

    def _check_event_trigger_archetype(self: TypeCheckPass, nd: uni.Ability) -> None;
}

"""Typed-tree contract inference entry: identical analysis to TypeCheckPass
(populates Expr.type for every backend), but non-ICE diagnostics are only
surfaced when the compile asked for them (options.type_check) or the module
is native-context (#6049). Scheduled by get_inference_sched for every
codegen-bearing compile."""
class TypeInferencePass(TypeCheckPass) {
    static has inference_only: bool = True;
}
