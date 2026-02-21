"""
UnparsePass for Jac AST.

Serializes AST nodes to source code strings stored in node.gen.jac.
Replaces the per-node normalize/unparse methods with a centralized pass.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.helpers { pascal_to_snake }

"""Serialize Jac AST nodes to source code strings."""
obj UnparsePass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def _comma_sep(nodes: list) -> str;
    def exit_node(nd: uni.UniNode) -> None;
    # Token types
    def exit_token(nd: uni.Token) -> None;
    def exit_name(nd: uni.Name) -> None;
    def exit_string(nd: uni.String) -> None;
    def exit_semi(nd: uni.Semi) -> None;
    def exit_int(nd: uni.Int) -> None;
    def exit_float(nd: uni.Float) -> None;
    def exit_bool(nd: uni.Bool) -> None;
    def exit_null(nd: uni.Null) -> None;
    def exit_ellipsis(nd: uni.Ellipsis) -> None;
    def exit_builtin_type(nd: uni.BuiltinType) -> None;
    def exit_special_var_ref(nd: uni.SpecialVarRef) -> None;
    # Module level
    def exit_module(nd: uni.Module) -> None;
    def exit_sub_tag(nd: uni.SubTag) -> None;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_type_param(nd: uni.TypeParam) -> None;
    def exit_global_vars(nd: uni.GlobalVars) -> None;
    def exit_test(nd: uni.Test) -> None;
    # Blocks
    def exit_module_code(nd: uni.ModuleCode) -> None;
    def exit_client_block(nd: uni.ClientBlock) -> None;
    def exit_server_block(nd: uni.ServerBlock) -> None;
    def exit_native_block(nd: uni.NativeBlock) -> None;
    def exit_py_inline_code(nd: uni.PyInlineCode) -> None;
    # Imports
    def exit_import(nd: uni.Import) -> None;
    def exit_module_path(nd: uni.ModulePath) -> None;
    def exit_module_item(nd: uni.ModuleItem) -> None;
    # Definitions
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def exit_sem_def(nd: uni.SemDef) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_func_signature(nd: uni.FuncSignature) -> None;
    def exit_event_signature(nd: uni.EventSignature) -> None;
    def exit_param_var(nd: uni.ParamVar) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_has_var(nd: uni.HasVar) -> None;
    def exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    # Control flow
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    def exit_expr_stmt(nd: uni.ExprStmt) -> None;
    def exit_try_stmt(nd: uni.TryStmt) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_finally_stmt(nd: uni.FinallyStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_with_stmt(nd: uni.WithStmt) -> None;
    def exit_expr_as_item(nd: uni.ExprAsItem) -> None;
    def exit_raise_stmt(nd: uni.RaiseStmt) -> None;
    def exit_assert_stmt(nd: uni.AssertStmt) -> None;
    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def exit_delete_stmt(nd: uni.DeleteStmt) -> None;
    def exit_report_stmt(nd: uni.ReportStmt) -> None;
    def exit_return_stmt(nd: uni.ReturnStmt) -> None;
    def exit_visit_stmt(nd: uni.VisitStmt) -> None;
    def exit_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def exit_await_expr(nd: uni.AwaitExpr) -> None;
    def exit_global_stmt(nd: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(nd: uni.NonLocalStmt) -> None;
    # Assignments
    def exit_assignment(nd: uni.Assignment) -> None;
    # Expressions
    def exit_concurrent_expr(nd: uni.ConcurrentExpr) -> None;
    def exit_binary_expr(nd: uni.BinaryExpr) -> None;
    def exit_compare_expr(nd: uni.CompareExpr) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_lambda_expr(nd: uni.LambdaExpr) -> None;
    def exit_unary_expr(nd: uni.UnaryExpr) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    def exit_multi_string(nd: uni.MultiString) -> None;
    def exit_f_string(nd: uni.FString) -> None;
    def exit_formatted_value(nd: uni.FormattedValue) -> None;
    def exit_list_val(nd: uni.ListVal) -> None;
    def exit_set_val(nd: uni.SetVal) -> None;
    def exit_tuple_val(nd: uni.TupleVal) -> None;
    def exit_dict_val(nd: uni.DictVal) -> None;
    def exit_k_v_pair(nd: uni.KVPair) -> None;
    def exit_k_w_pair(nd: uni.KWPair) -> None;
    def exit_inner_compr(nd: uni.InnerCompr) -> None;
    def exit_list_compr(nd: uni.ListCompr) -> None;
    def exit_gen_compr(nd: uni.GenCompr) -> None;
    def exit_set_compr(nd: uni.SetCompr) -> None;
    def exit_dict_compr(nd: uni.DictCompr) -> None;
    def exit_atom_trailer(nd: uni.AtomTrailer) -> None;
    def exit_atom_unit(nd: uni.AtomUnit) -> None;
    def exit_yield_expr(nd: uni.YieldExpr) -> None;
    def exit_func_call(nd: uni.FuncCall) -> None;
    def exit_index_slice(nd: uni.IndexSlice) -> None;
    def exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(nd: uni.EdgeOpRef) -> None;
    def exit_disconnect_op(nd: uni.DisconnectOp) -> None;
    def exit_connect_op(nd: uni.ConnectOp) -> None;
    def exit_filter_compr(nd: uni.FilterCompr) -> None;
    def exit_assign_compr(nd: uni.AssignCompr) -> None;
    # JSX
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_jsx_element_name(nd: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;
    def exit_jsx_text(nd: uni.JsxText) -> None;
    def exit_jsx_expression(nd: uni.JsxExpression) -> None;
    # Match / Switch
    def exit_match_stmt(nd: uni.MatchStmt) -> None;
    def exit_match_case(nd: uni.MatchCase) -> None;
    def exit_switch_stmt(nd: uni.SwitchStmt) -> None;
    def exit_switch_case(nd: uni.SwitchCase) -> None;
    def exit_match_or(nd: uni.MatchOr) -> None;
    def exit_match_as(nd: uni.MatchAs) -> None;
    def exit_match_wild(nd: uni.MatchWild) -> None;
    def exit_match_value(nd: uni.MatchValue) -> None;
    def exit_match_singleton(nd: uni.MatchSingleton) -> None;
    def exit_match_sequence(nd: uni.MatchSequence) -> None;
    def exit_match_mapping(nd: uni.MatchMapping) -> None;
    def exit_match_k_v_pair(nd: uni.MatchKVPair) -> None;
    def exit_match_star(nd: uni.MatchStar) -> None;
    def exit_match_arch(nd: uni.MatchArch) -> None;
}
