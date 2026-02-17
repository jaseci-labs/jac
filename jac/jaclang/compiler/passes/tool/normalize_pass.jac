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
    def enter_sub_tag(nd: uni.SubTag) -> None;
    def enter_module(nd: uni.Module) -> None;
    def enter_global_vars(nd: uni.GlobalVars) -> None;
    def enter_test(nd: uni.Test) -> None;
    def enter_module_code(nd: uni.ModuleCode) -> None;
    def enter_client_block(nd: uni.ClientBlock) -> None;
    def enter_server_block(nd: uni.ServerBlock) -> None;
    def enter_native_block(nd: uni.NativeBlock) -> None;
    def enter_py_inline_code(nd: uni.PyInlineCode) -> None;
    def enter_import(nd: uni.Import) -> None;
    def enter_module_path(nd: uni.ModulePath) -> None;
    def enter_module_item(nd: uni.ModuleItem) -> None;
    def enter_archetype(nd: uni.Archetype) -> None;
    def enter_impl_def(nd: uni.ImplDef) -> None;
    def enter_sem_def(nd: uni.SemDef) -> None;
    def enter_enum(nd: uni.Enum) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def enter_func_signature(nd: uni.FuncSignature) -> None;
    def enter_event_signature(nd: uni.EventSignature) -> None;
    def enter_param_var(nd: uni.ParamVar) -> None;
    def enter_arch_has(nd: uni.ArchHas) -> None;
    def enter_has_var(nd: uni.HasVar) -> None;
    def enter_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_else_if(nd: uni.ElseIf) -> None;
    def enter_else_stmt(nd: uni.ElseStmt) -> None;
    def enter_expr_stmt(nd: uni.ExprStmt) -> None;
    def enter_try_stmt(nd: uni.TryStmt) -> None;
    def enter_except(nd: uni.Except) -> None;
    def enter_finally_stmt(nd: uni.FinallyStmt) -> None;
    def enter_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def enter_in_for_stmt(nd: uni.InForStmt) -> None;
    def enter_while_stmt(nd: uni.WhileStmt) -> None;
    def enter_with_stmt(nd: uni.WithStmt) -> None;
    def enter_expr_as_item(nd: uni.ExprAsItem) -> None;
    def enter_raise_stmt(nd: uni.RaiseStmt) -> None;
    def enter_assert_stmt(nd: uni.AssertStmt) -> None;
    def enter_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def enter_delete_stmt(nd: uni.DeleteStmt) -> None;
    def enter_report_stmt(nd: uni.ReportStmt) -> None;
    def enter_return_stmt(nd: uni.ReturnStmt) -> None;
    def enter_visit_stmt(nd: uni.VisitStmt) -> None;
    def enter_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def enter_await_expr(nd: uni.AwaitExpr) -> None;
    def enter_global_stmt(nd: uni.GlobalStmt) -> None;
    def enter_non_local_stmt(nd: uni.NonLocalStmt) -> None;
    def enter_assignment(nd: uni.Assignment) -> None;
    def enter_concurrent_expr(nd: uni.ConcurrentExpr) -> None;
    def enter_binary_expr(nd: uni.BinaryExpr) -> None;
    def enter_compare_expr(nd: uni.CompareExpr) -> None;
    def enter_bool_expr(nd: uni.BoolExpr) -> None;
    def enter_lambda_expr(nd: uni.LambdaExpr) -> None;
    def enter_unary_expr(nd: uni.UnaryExpr) -> None;
    def enter_if_else_expr(nd: uni.IfElseExpr) -> None;
    def enter_multi_string(nd: uni.MultiString) -> None;
    def enter_f_string(nd: uni.FString) -> None;
    def enter_formatted_value(nd: uni.FormattedValue) -> None;
    def enter_list_val(nd: uni.ListVal) -> None;
    def enter_set_val(nd: uni.SetVal) -> None;
    def enter_tuple_val(nd: uni.TupleVal) -> None;
    def enter_dict_val(nd: uni.DictVal) -> None;
    def enter_k_v_pair(nd: uni.KVPair) -> None;
    def enter_k_w_pair(nd: uni.KWPair) -> None;
    def enter_inner_compr(nd: uni.InnerCompr) -> None;
    def enter_list_compr(nd: uni.ListCompr) -> None;
    def enter_gen_compr(nd: uni.GenCompr) -> None;
    def enter_set_compr(nd: uni.SetCompr) -> None;
    def enter_dict_compr(nd: uni.DictCompr) -> None;
    def enter_atom_trailer(nd: uni.AtomTrailer) -> None;
    def enter_atom_unit(nd: uni.AtomUnit) -> None;
    def enter_yield_expr(nd: uni.YieldExpr) -> None;
    def enter_func_call(nd: uni.FuncCall) -> None;
    def enter_index_slice(nd: uni.IndexSlice) -> None;
    def enter_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None;
    def enter_edge_op_ref(nd: uni.EdgeOpRef) -> None;
    def enter_disconnect_op(nd: uni.DisconnectOp) -> None;
    def enter_connect_op(nd: uni.ConnectOp) -> None;
    def enter_filter_compr(nd: uni.FilterCompr) -> None;
    def enter_assign_compr(nd: uni.AssignCompr) -> None;
    def enter_jsx_attribute(nd: uni.JsxAttribute) -> None;
    def enter_jsx_child(nd: uni.JsxChild) -> None;
    def enter_jsx_element(nd: uni.JsxElement) -> None;
    def enter_jsx_element_name(nd: uni.JsxElementName) -> None;
    def enter_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;
    def enter_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;
    def enter_jsx_text(nd: uni.JsxText) -> None;
    def enter_jsx_expression(nd: uni.JsxExpression) -> None;
    def enter_match_stmt(nd: uni.MatchStmt) -> None;
    def enter_match_case(nd: uni.MatchCase) -> None;
    def enter_switch_stmt(nd: uni.SwitchStmt) -> None;
    def enter_switch_case(nd: uni.SwitchCase) -> None;
    def enter_match_or(nd: uni.MatchOr) -> None;
    def enter_match_as(nd: uni.MatchAs) -> None;
    def enter_match_wild(nd: uni.MatchWild) -> None;
    def enter_match_value(nd: uni.MatchValue) -> None;
    def enter_match_singleton(nd: uni.MatchSingleton) -> None;
    def enter_match_sequence(nd: uni.MatchSequence) -> None;
    def enter_match_mapping(nd: uni.MatchMapping) -> None;
    def enter_match_k_v_pair(nd: uni.MatchKVPair) -> None;
    def enter_match_star(nd: uni.MatchStar) -> None;
    def enter_match_arch(nd: uni.MatchArch) -> None;
    def enter_token(nd: uni.Token) -> None;
    def enter_string(nd: uni.String) -> None;
}
