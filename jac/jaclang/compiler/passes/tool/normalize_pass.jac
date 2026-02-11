"""
NormalizePass: rebuilds kid lists from semantic fields.

This pass traverses the AST using enter_* methods (pre-order)
to rebuild each node's kid list from its semantic fields.
This is needed before passes that read .kid (e.g., DocIRGenPass).
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { CodeContext, EdgeDir }
import from jaclang.jac0core.unitree { Tok, EmptyToken, Token }

"""Rebuild kid lists from semantic fields."""
obj NormalizePass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def enter_sub_tag(`node: uni.SubTag) -> None;
    def enter_module(`node: uni.Module) -> None;
    def enter_global_vars(`node: uni.GlobalVars) -> None;
    def enter_test(`node: uni.Test) -> None;
    def enter_module_code(`node: uni.ModuleCode) -> None;
    def enter_client_block(`node: uni.ClientBlock) -> None;
    def enter_server_block(`node: uni.ServerBlock) -> None;
    def enter_native_block(`node: uni.NativeBlock) -> None;
    def enter_py_inline_code(`node: uni.PyInlineCode) -> None;
    def enter_import(`node: uni.Import) -> None;
    def enter_module_path(`node: uni.ModulePath) -> None;
    def enter_module_item(`node: uni.ModuleItem) -> None;
    def enter_archetype(`node: uni.Archetype) -> None;
    def enter_impl_def(`node: uni.ImplDef) -> None;
    def enter_sem_def(`node: uni.SemDef) -> None;
    def enter_enum(`node: uni.Enum) -> None;
    def enter_ability(`node: uni.Ability) -> None;
    def enter_func_signature(`node: uni.FuncSignature) -> None;
    def enter_event_signature(`node: uni.EventSignature) -> None;
    def enter_param_var(`node: uni.ParamVar) -> None;
    def enter_arch_has(`node: uni.ArchHas) -> None;
    def enter_has_var(`node: uni.HasVar) -> None;
    def enter_typed_ctx_block(`node: uni.TypedCtxBlock) -> None;
    def enter_if_stmt(`node: uni.IfStmt) -> None;
    def enter_else_if(`node: uni.ElseIf) -> None;
    def enter_else_stmt(`node: uni.ElseStmt) -> None;
    def enter_expr_stmt(`node: uni.ExprStmt) -> None;
    def enter_try_stmt(`node: uni.TryStmt) -> None;
    def enter_except(`node: uni.Except) -> None;
    def enter_finally_stmt(`node: uni.FinallyStmt) -> None;
    def enter_iter_for_stmt(`node: uni.IterForStmt) -> None;
    def enter_in_for_stmt(`node: uni.InForStmt) -> None;
    def enter_while_stmt(`node: uni.WhileStmt) -> None;
    def enter_with_stmt(`node: uni.WithStmt) -> None;
    def enter_expr_as_item(`node: uni.ExprAsItem) -> None;
    def enter_raise_stmt(`node: uni.RaiseStmt) -> None;
    def enter_assert_stmt(`node: uni.AssertStmt) -> None;
    def enter_ctrl_stmt(`node: uni.CtrlStmt) -> None;
    def enter_delete_stmt(`node: uni.DeleteStmt) -> None;
    def enter_report_stmt(`node: uni.ReportStmt) -> None;
    def enter_return_stmt(`node: uni.ReturnStmt) -> None;
    def enter_visit_stmt(`node: uni.VisitStmt) -> None;
    def enter_disengage_stmt(`node: uni.DisengageStmt) -> None;
    def enter_await_expr(`node: uni.AwaitExpr) -> None;
    def enter_global_stmt(`node: uni.GlobalStmt) -> None;
    def enter_non_local_stmt(`node: uni.NonLocalStmt) -> None;
    def enter_assignment(`node: uni.Assignment) -> None;
    def enter_concurrent_expr(`node: uni.ConcurrentExpr) -> None;
    def enter_binary_expr(`node: uni.BinaryExpr) -> None;
    def enter_compare_expr(`node: uni.CompareExpr) -> None;
    def enter_bool_expr(`node: uni.BoolExpr) -> None;
    def enter_lambda_expr(`node: uni.LambdaExpr) -> None;
    def enter_unary_expr(`node: uni.UnaryExpr) -> None;
    def enter_if_else_expr(`node: uni.IfElseExpr) -> None;
    def enter_multi_string(`node: uni.MultiString) -> None;
    def enter_f_string(`node: uni.FString) -> None;
    def enter_formatted_value(`node: uni.FormattedValue) -> None;
    def enter_list_val(`node: uni.ListVal) -> None;
    def enter_set_val(`node: uni.SetVal) -> None;
    def enter_tuple_val(`node: uni.TupleVal) -> None;
    def enter_dict_val(`node: uni.DictVal) -> None;
    def enter_k_v_pair(`node: uni.KVPair) -> None;
    def enter_k_w_pair(`node: uni.KWPair) -> None;
    def enter_inner_compr(`node: uni.InnerCompr) -> None;
    def enter_list_compr(`node: uni.ListCompr) -> None;
    def enter_gen_compr(`node: uni.GenCompr) -> None;
    def enter_set_compr(`node: uni.SetCompr) -> None;
    def enter_dict_compr(`node: uni.DictCompr) -> None;
    def enter_atom_trailer(`node: uni.AtomTrailer) -> None;
    def enter_atom_unit(`node: uni.AtomUnit) -> None;
    def enter_yield_expr(`node: uni.YieldExpr) -> None;
    def enter_func_call(`node: uni.FuncCall) -> None;
    def enter_index_slice(`node: uni.IndexSlice) -> None;
    def enter_edge_ref_trailer(`node: uni.EdgeRefTrailer) -> None;
    def enter_edge_op_ref(`node: uni.EdgeOpRef) -> None;
    def enter_disconnect_op(`node: uni.DisconnectOp) -> None;
    def enter_connect_op(`node: uni.ConnectOp) -> None;
    def enter_filter_compr(`node: uni.FilterCompr) -> None;
    def enter_assign_compr(`node: uni.AssignCompr) -> None;
    def enter_jsx_attribute(`node: uni.JsxAttribute) -> None;
    def enter_jsx_child(`node: uni.JsxChild) -> None;
    def enter_jsx_element(`node: uni.JsxElement) -> None;
    def enter_jsx_element_name(`node: uni.JsxElementName) -> None;
    def enter_jsx_spread_attribute(`node: uni.JsxSpreadAttribute) -> None;
    def enter_jsx_normal_attribute(`node: uni.JsxNormalAttribute) -> None;
    def enter_jsx_text(`node: uni.JsxText) -> None;
    def enter_jsx_expression(`node: uni.JsxExpression) -> None;
    def enter_match_stmt(`node: uni.MatchStmt) -> None;
    def enter_match_case(`node: uni.MatchCase) -> None;
    def enter_switch_stmt(`node: uni.SwitchStmt) -> None;
    def enter_switch_case(`node: uni.SwitchCase) -> None;
    def enter_match_or(`node: uni.MatchOr) -> None;
    def enter_match_as(`node: uni.MatchAs) -> None;
    def enter_match_wild(`node: uni.MatchWild) -> None;
    def enter_match_value(`node: uni.MatchValue) -> None;
    def enter_match_singleton(`node: uni.MatchSingleton) -> None;
    def enter_match_sequence(`node: uni.MatchSequence) -> None;
    def enter_match_mapping(`node: uni.MatchMapping) -> None;
    def enter_match_k_v_pair(`node: uni.MatchKVPair) -> None;
    def enter_match_star(`node: uni.MatchStar) -> None;
    def enter_match_arch(`node: uni.MatchArch) -> None;
    def enter_token(`node: uni.Token) -> None;
    def enter_string(`node: uni.String) -> None;
}
