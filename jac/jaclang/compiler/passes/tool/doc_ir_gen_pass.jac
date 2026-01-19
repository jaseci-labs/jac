"""
DocIrGenPass for Jaseci Ast.

This is a pass for generating DocIr for Jac code.
"""
import from collections.abc { Sequence }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes { UniPass }
"""DocIrGenPass generate DocIr for Jac code."""
obj DocIRGenPass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def text(text: str, source_token: (uni.Token | None) = None) -> doc.Text;
    def space -> doc.Text;
    def line(hard: bool = False, literal: bool = False) -> doc.Line;
    def hard_line -> doc.Line;
    def tight_line -> doc.Line;
    def literal_line -> doc.Line;
    def group(
        contents: doc.DocType,
        break_contiguous: bool = False,
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Group;

    def indent(
        contents: doc.DocType, ast_node: (uni.UniNode | None) = None
    ) -> doc.Indent;

    def concat(
        parts: list[doc.DocType], ast_node: (uni.UniNode | None) = None
    ) -> doc.Concat;

    def if_break(
        break_contents: doc.DocType, flat_contents: doc.DocType
    ) -> doc.IfBreak;

    def align(contents: doc.DocType, n: (int | None) = None) -> doc.Align;
    def join(separator: doc.DocType, parts: list[doc.DocType]) -> doc.DocType;
    def join_with_space(parts: list[doc.DocType]) -> doc.DocType;
    def join_with_line(parts: list[doc.DocType]) -> doc.DocType;
    def _child_docs(<>node: uni.UniNode) -> list[doc.DocType];
    def _assign_concat(<>node: uni.UniNode) -> None;
    def _assign_group_concat(<>node: uni.UniNode) -> None;
    def _assign_space_group(<>node: uni.UniNode) -> None;
    def intersperse(
        items: list[doc.DocType], separator: doc.DocType
    ) -> list[doc.DocType];

    def format_simple_stmt_with_body(
        <>node: uni.UniNode,
        body: Sequence[uni.UniNode],
        space_between_parts: bool = True
    ) -> doc.DocType;

    def format_comprehension(parts: list[doc.DocType]) -> doc.DocType;
    def is_one_line(<>node: uni.UniNode) -> bool;
    def has_gap(prev_kid: uni.UniNode, curr_kid: uni.UniNode) -> bool;
    def add_body_stmt_with_spacing(
        body_parts: list[doc.DocType],
        current: uni.UniNode,
        previous: (uni.UniNode | None)
    ) -> None;

    def is_within(kid_node: uni.UniNode, block: Sequence[uni.UniNode]) -> bool;
    def trim_trailing_line(parts: list[doc.DocType]) -> None;
    def remove_all_spaces(doc_node: doc.DocType) -> doc.DocType;
    def exit_module(<>node: uni.Module) -> None;
    def exit_import(<>node: uni.Import) -> None;
    def exit_module_item(<>node: uni.ModuleItem) -> None;
    def exit_module_path(<>node: uni.ModulePath) -> None;
    def exit_archetype(<>node: uni.Archetype) -> None;
    def exit_ability(<>node: uni.Ability) -> None;
    def exit_func_signature(<>node: uni.FuncSignature) -> None;
    def exit_param_var(<>node: uni.ParamVar) -> None;
    def exit_type_ref(<>node: uni.TypeRef) -> None;
    def exit_assignment(<>node: uni.Assignment) -> None;
    def exit_if_stmt(<>node: uni.IfStmt) -> None;
    def exit_else_if(<>node: uni.ElseIf) -> None;
    def exit_else_stmt(<>node: uni.ElseStmt) -> None;
    def exit_binary_expr(<>node: uni.BinaryExpr) -> None;
    def exit_expr_stmt(<>node: uni.ExprStmt) -> None;
    def exit_concurrent_expr(<>node: uni.ConcurrentExpr) -> None;
    def exit_return_stmt(<>node: uni.ReturnStmt) -> None;
    def exit_func_call(<>node: uni.FuncCall) -> None;
    def exit_atom_trailer(<>node: uni.AtomTrailer) -> None;
    def exit_list_val(<>node: uni.ListVal) -> None;
    def exit_dict_val(<>node: uni.DictVal) -> None;
    def exit_k_v_pair(<>node: uni.KVPair) -> None;
    def exit_has_var(<>node: uni.HasVar) -> None;
    def exit_arch_has(<>node: uni.ArchHas) -> None;
    def exit_while_stmt(<>node: uni.WhileStmt) -> None;
    def exit_in_for_stmt(<>node: uni.InForStmt) -> None;
    def exit_iter_for_stmt(<>node: uni.IterForStmt) -> None;
    def exit_try_stmt(<>node: uni.TryStmt) -> None;
    def exit_except(<>node: uni.Except) -> None;
    def exit_finally_stmt(<>node: uni.FinallyStmt) -> None;
    def exit_tuple_val(<>node: uni.TupleVal) -> None;
    def exit_multi_string(<>node: uni.MultiString) -> None;
    def exit_set_val(<>node: uni.SetVal) -> None;
    def exit_with_stmt(<>node: uni.WithStmt) -> None;
    def exit_list_compr(<>node: uni.ListCompr) -> None;
    def exit_inner_compr(<>node: uni.InnerCompr) -> None;
    def exit_f_string(<>node: uni.FString) -> None;
    def exit_formatted_value(<>node: uni.FormattedValue) -> None;
    def exit_if_else_expr(<>node: uni.IfElseExpr) -> None;
    def exit_bool_expr(<>node: uni.BoolExpr) -> None;
    def exit_unary_expr(<>node: uni.UnaryExpr) -> None;
    def exit_lambda_expr(<>node: uni.LambdaExpr) -> None;
    def exit_edge_ref_trailer(<>node: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(<>node: uni.EdgeOpRef) -> None;
    def exit_index_slice(<>node: uni.IndexSlice) -> None;
    def exit_gen_compr(<>node: uni.GenCompr) -> None;
    def exit_set_compr(<>node: uni.SetCompr) -> None;
    def exit_dict_compr(<>node: uni.DictCompr) -> None;
    def exit_k_w_pair(<>node: uni.KWPair) -> None;
    def exit_await_expr(<>node: uni.AwaitExpr) -> None;
    def exit_yield_expr(<>node: uni.YieldExpr) -> None;
    def exit_ctrl_stmt(<>node: uni.CtrlStmt) -> None;
    def exit_delete_stmt(<>node: uni.DeleteStmt) -> None;
    def exit_disengage_stmt(<>node: uni.DisengageStmt) -> None;
    def exit_report_stmt(<>node: uni.ReportStmt) -> None;
    def exit_assert_stmt(<>node: uni.AssertStmt) -> None;
    def exit_raise_stmt(<>node: uni.RaiseStmt) -> None;
    def exit_global_vars(<>node: uni.GlobalVars) -> None;
    def exit_client_block(<>node: uni.ClientBlock) -> None;
    def exit_server_block(<>node: uni.ServerBlock) -> None;
    def exit_module_code(<>node: uni.ModuleCode) -> None;
    def exit_global_stmt(<>node: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None;
    def exit_visit_stmt(<>node: uni.VisitStmt) -> None;
    def exit_connect_op(<>node: uni.ConnectOp) -> None;
    def exit_disconnect_op(<>node: uni.DisconnectOp) -> None;
    def exit_compare_expr(<>node: uni.CompareExpr) -> None;
    def exit_atom_unit(<>node: uni.AtomUnit) -> None;
    def exit_expr_as_item(<>node: uni.ExprAsItem) -> None;
    def exit_filter_compr(<>node: uni.FilterCompr) -> None;
    def exit_assign_compr(<>node: uni.AssignCompr) -> None;
    def exit_py_inline_code(<>node: uni.PyInlineCode) -> None;
    def exit_test(<>node: uni.Test) -> None;
    def exit_match_stmt(<>node: uni.MatchStmt) -> None;
    def exit_match_case(<>node: uni.MatchCase) -> None;
    def exit_switch_stmt(<>node: uni.SwitchStmt) -> None;
    def exit_switch_case(<>node: uni.SwitchCase) -> None;
    def exit_match_value(<>node: uni.MatchValue) -> None;
    def exit_match_singleton(<>node: uni.MatchSingleton) -> None;
    def exit_match_sequence(<>node: uni.MatchSequence) -> None;
    def exit_match_mapping(<>node: uni.MatchMapping) -> None;
    def exit_match_or(<>node: uni.MatchOr) -> None;
    def exit_match_as(<>node: uni.MatchAs) -> None;
    def exit_match_wild(<>node: uni.MatchWild) -> None;
    def exit_match_star(<>node: uni.MatchStar) -> None;
    def exit_match_k_v_pair(<>node: uni.MatchKVPair) -> None;
    def exit_match_arch(<>node: uni.MatchArch) -> None;
    def exit_enum(<>node: uni.Enum) -> None;
    def exit_sub_tag(<>node: uni.SubTag) -> None;
    def exit_impl_def(<>node: uni.ImplDef) -> None;
    def exit_sem_def(<>node: uni.SemDef) -> None;
    def exit_event_signature(<>node: uni.EventSignature) -> None;
    def exit_typed_ctx_block(<>node: uni.TypedCtxBlock) -> None;
    def exit_token(<>node: uni.Token) -> None;
    def exit_semi(<>node: uni.Semi) -> None;
    def exit_name(<>node: uni.Name) -> None;
    def exit_int(<>node: uni.Int) -> None;
    def exit_builtin_type(<>node: uni.BuiltinType) -> None;
    def exit_float(<>node: uni.Float) -> None;
    def exit_string(<>node: uni.String) -> None;
    def exit_special_var_ref(<>node: uni.SpecialVarRef) -> None;
    def exit_bool(<>node: uni.Bool) -> None;
    def exit_null(<>node: uni.Null) -> None;
    def exit_ellipsis(<>node: uni.Ellipsis) -> None;
    def exit_jsx_element(<>node: uni.JsxElement) -> None;
    def exit_jsx_element_name(<>node: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(<>node: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(<>node: uni.JsxNormalAttribute) -> None;
    def exit_jsx_text(<>node: uni.JsxText) -> None;
    def exit_jsx_expression(<>node: uni.JsxExpression) -> None;
}
