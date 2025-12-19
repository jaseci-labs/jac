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
class DocIRGenPass(UniPass) {
    def text(
        self: DocIRGenPass, text: str, source_token: (uni.Token | None) = None
    ) -> doc.Text;

    def space(self: DocIRGenPass) -> doc.Text;
    def line(self: DocIRGenPass, hard: bool = False, literal: bool = False) -> doc.Line;
    def hard_line(self: DocIRGenPass) -> doc.Line;
    def tight_line(self: DocIRGenPass) -> doc.Line;
    def literal_line(self: DocIRGenPass) -> doc.Line;
    def group(
        self: DocIRGenPass,
        contents: doc.DocType,
        break_contiguous: bool = False,
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Group;

    def indent(
        self: DocIRGenPass,
        contents: doc.DocType,
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Indent;

    def concat(
        self: DocIRGenPass,
        parts: list[doc.DocType],
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Concat;

    def if_break(
        self: DocIRGenPass, break_contents: doc.DocType, flat_contents: doc.DocType
    ) -> doc.IfBreak;

    def align(
        self: DocIRGenPass, contents: doc.DocType, n: (int | None) = None
    ) -> doc.Align;

    def join(
        self: DocIRGenPass, separator: doc.DocType, parts: list[doc.DocType]
    ) -> doc.DocType;

    def join_with_space(self: DocIRGenPass, parts: list[doc.DocType]) -> doc.DocType;
    def join_with_line(self: DocIRGenPass, parts: list[doc.DocType]) -> doc.DocType;
    def _child_docs(self: DocIRGenPass, <>node: uni.UniNode) -> list[doc.DocType];
    def _assign_concat(self: DocIRGenPass, <>node: uni.UniNode) -> None;
    def _assign_group_concat(self: DocIRGenPass, <>node: uni.UniNode) -> None;
    def _assign_space_group(self: DocIRGenPass, <>node: uni.UniNode) -> None;
    def intersperse(
        self: DocIRGenPass, items: list[doc.DocType], separator: doc.DocType
    ) -> list[doc.DocType];

    def format_simple_stmt_with_body(
        self: DocIRGenPass,
        <>node: uni.UniNode,
        body: Sequence[uni.UniNode],
        space_between_parts: bool = True
    ) -> doc.DocType;

    def format_comprehension(
        self: DocIRGenPass, parts: list[doc.DocType]
    ) -> doc.DocType;

    def is_one_line(self: DocIRGenPass, <>node: uni.UniNode) -> bool;
    def has_gap(
        self: DocIRGenPass, prev_kid: uni.UniNode, curr_kid: uni.UniNode
    ) -> bool;

    def add_body_stmt_with_spacing(
        self: DocIRGenPass,
        body_parts: list[doc.DocType],
        current: uni.UniNode,
        previous: (uni.UniNode | None)
    ) -> None;

    def is_within(
        self: DocIRGenPass, kid_node: uni.UniNode, block: Sequence[uni.UniNode]
    ) -> bool;

    def trim_trailing_line(self: DocIRGenPass, parts: list[doc.DocType]) -> None;
    def remove_all_spaces(self: DocIRGenPass, doc_node: doc.DocType) -> doc.DocType;
    def exit_module(self: DocIRGenPass, <>node: uni.Module) -> None;
    def exit_import(self: DocIRGenPass, <>node: uni.Import) -> None;
    def exit_module_item(self: DocIRGenPass, <>node: uni.ModuleItem) -> None;
    def exit_module_path(self: DocIRGenPass, <>node: uni.ModulePath) -> None;
    def exit_archetype(self: DocIRGenPass, <>node: uni.Archetype) -> None;
    def exit_ability(self: DocIRGenPass, <>node: uni.Ability) -> None;
    def exit_func_signature(self: DocIRGenPass, <>node: uni.FuncSignature) -> None;
    def exit_param_var(self: DocIRGenPass, <>node: uni.ParamVar) -> None;
    def exit_type_ref(self: DocIRGenPass, <>node: uni.TypeRef) -> None;
    def exit_assignment(self: DocIRGenPass, <>node: uni.Assignment) -> None;
    def exit_if_stmt(self: DocIRGenPass, <>node: uni.IfStmt) -> None;
    def exit_else_if(self: DocIRGenPass, <>node: uni.ElseIf) -> None;
    def exit_else_stmt(self: DocIRGenPass, <>node: uni.ElseStmt) -> None;
    def exit_binary_expr(self: DocIRGenPass, <>node: uni.BinaryExpr) -> None;
    def exit_expr_stmt(self: DocIRGenPass, <>node: uni.ExprStmt) -> None;
    def exit_concurrent_expr(self: DocIRGenPass, <>node: uni.ConcurrentExpr) -> None;
    def exit_return_stmt(self: DocIRGenPass, <>node: uni.ReturnStmt) -> None;
    def exit_func_call(self: DocIRGenPass, <>node: uni.FuncCall) -> None;
    def exit_atom_trailer(self: DocIRGenPass, <>node: uni.AtomTrailer) -> None;
    def exit_list_val(self: DocIRGenPass, <>node: uni.ListVal) -> None;
    def exit_dict_val(self: DocIRGenPass, <>node: uni.DictVal) -> None;
    def exit_k_v_pair(self: DocIRGenPass, <>node: uni.KVPair) -> None;
    def exit_has_var(self: DocIRGenPass, <>node: uni.HasVar) -> None;
    def exit_arch_has(self: DocIRGenPass, <>node: uni.ArchHas) -> None;
    def exit_while_stmt(self: DocIRGenPass, <>node: uni.WhileStmt) -> None;
    def exit_in_for_stmt(self: DocIRGenPass, <>node: uni.InForStmt) -> None;
    def exit_iter_for_stmt(self: DocIRGenPass, <>node: uni.IterForStmt) -> None;
    def exit_try_stmt(self: DocIRGenPass, <>node: uni.TryStmt) -> None;
    def exit_except(self: DocIRGenPass, <>node: uni.Except) -> None;
    def exit_finally_stmt(self: DocIRGenPass, <>node: uni.FinallyStmt) -> None;
    def exit_tuple_val(self: DocIRGenPass, <>node: uni.TupleVal) -> None;
    def exit_multi_string(self: DocIRGenPass, <>node: uni.MultiString) -> None;
    def exit_set_val(self: DocIRGenPass, <>node: uni.SetVal) -> None;
    def exit_with_stmt(self: DocIRGenPass, <>node: uni.WithStmt) -> None;
    def exit_list_compr(self: DocIRGenPass, <>node: uni.ListCompr) -> None;
    def exit_inner_compr(self: DocIRGenPass, <>node: uni.InnerCompr) -> None;
    def exit_f_string(self: DocIRGenPass, <>node: uni.FString) -> None;
    def exit_formatted_value(self: DocIRGenPass, <>node: uni.FormattedValue) -> None;
    def exit_if_else_expr(self: DocIRGenPass, <>node: uni.IfElseExpr) -> None;
    def exit_bool_expr(self: DocIRGenPass, <>node: uni.BoolExpr) -> None;
    def exit_unary_expr(self: DocIRGenPass, <>node: uni.UnaryExpr) -> None;
    def exit_lambda_expr(self: DocIRGenPass, <>node: uni.LambdaExpr) -> None;
    def exit_edge_ref_trailer(self: DocIRGenPass, <>node: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(self: DocIRGenPass, <>node: uni.EdgeOpRef) -> None;
    def exit_index_slice(self: DocIRGenPass, <>node: uni.IndexSlice) -> None;
    def exit_gen_compr(self: DocIRGenPass, <>node: uni.GenCompr) -> None;
    def exit_set_compr(self: DocIRGenPass, <>node: uni.SetCompr) -> None;
    def exit_dict_compr(self: DocIRGenPass, <>node: uni.DictCompr) -> None;
    def exit_k_w_pair(self: DocIRGenPass, <>node: uni.KWPair) -> None;
    def exit_await_expr(self: DocIRGenPass, <>node: uni.AwaitExpr) -> None;
    def exit_yield_expr(self: DocIRGenPass, <>node: uni.YieldExpr) -> None;
    def exit_ctrl_stmt(self: DocIRGenPass, <>node: uni.CtrlStmt) -> None;
    def exit_delete_stmt(self: DocIRGenPass, <>node: uni.DeleteStmt) -> None;
    def exit_disengage_stmt(self: DocIRGenPass, <>node: uni.DisengageStmt) -> None;
    def exit_report_stmt(self: DocIRGenPass, <>node: uni.ReportStmt) -> None;
    def exit_assert_stmt(self: DocIRGenPass, <>node: uni.AssertStmt) -> None;
    def exit_raise_stmt(self: DocIRGenPass, <>node: uni.RaiseStmt) -> None;
    def exit_global_vars(self: DocIRGenPass, <>node: uni.GlobalVars) -> None;
    def exit_client_block(self: DocIRGenPass, <>node: uni.ClientBlock) -> None;
    def exit_module_code(self: DocIRGenPass, <>node: uni.ModuleCode) -> None;
    def exit_global_stmt(self: DocIRGenPass, <>node: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(self: DocIRGenPass, <>node: uni.NonLocalStmt) -> None;
    def exit_visit_stmt(self: DocIRGenPass, <>node: uni.VisitStmt) -> None;
    def exit_connect_op(self: DocIRGenPass, <>node: uni.ConnectOp) -> None;
    def exit_disconnect_op(self: DocIRGenPass, <>node: uni.DisconnectOp) -> None;
    def exit_compare_expr(self: DocIRGenPass, <>node: uni.CompareExpr) -> None;
    def exit_atom_unit(self: DocIRGenPass, <>node: uni.AtomUnit) -> None;
    def exit_expr_as_item(self: DocIRGenPass, <>node: uni.ExprAsItem) -> None;
    def exit_filter_compr(self: DocIRGenPass, <>node: uni.FilterCompr) -> None;
    def exit_assign_compr(self: DocIRGenPass, <>node: uni.AssignCompr) -> None;
    def exit_py_inline_code(self: DocIRGenPass, <>node: uni.PyInlineCode) -> None;
    def exit_test(self: DocIRGenPass, <>node: uni.Test) -> None;
    def exit_match_stmt(self: DocIRGenPass, <>node: uni.MatchStmt) -> None;
    def exit_match_case(self: DocIRGenPass, <>node: uni.MatchCase) -> None;
    def exit_switch_stmt(self: DocIRGenPass, <>node: uni.SwitchStmt) -> None;
    def exit_switch_case(self: DocIRGenPass, <>node: uni.SwitchCase) -> None;
    def exit_match_value(self: DocIRGenPass, <>node: uni.MatchValue) -> None;
    def exit_match_singleton(self: DocIRGenPass, <>node: uni.MatchSingleton) -> None;
    def exit_match_sequence(self: DocIRGenPass, <>node: uni.MatchSequence) -> None;
    def exit_match_mapping(self: DocIRGenPass, <>node: uni.MatchMapping) -> None;
    def exit_match_or(self: DocIRGenPass, <>node: uni.MatchOr) -> None;
    def exit_match_as(self: DocIRGenPass, <>node: uni.MatchAs) -> None;
    def exit_match_wild(self: DocIRGenPass, <>node: uni.MatchWild) -> None;
    def exit_match_star(self: DocIRGenPass, <>node: uni.MatchStar) -> None;
    def exit_match_k_v_pair(self: DocIRGenPass, <>node: uni.MatchKVPair) -> None;
    def exit_match_arch(self: DocIRGenPass, <>node: uni.MatchArch) -> None;
    def exit_enum(self: DocIRGenPass, <>node: uni.Enum) -> None;
    def exit_sub_tag(self: DocIRGenPass, <>node: uni.SubTag) -> None;
    def exit_impl_def(self: DocIRGenPass, <>node: uni.ImplDef) -> None;
    def exit_sem_def(self: DocIRGenPass, <>node: uni.SemDef) -> None;
    def exit_event_signature(self: DocIRGenPass, <>node: uni.EventSignature) -> None;
    def exit_typed_ctx_block(self: DocIRGenPass, <>node: uni.TypedCtxBlock) -> None;
    def exit_token(self: DocIRGenPass, <>node: uni.Token) -> None;
    def exit_semi(self: DocIRGenPass, <>node: uni.Semi) -> None;
    def exit_name(self: DocIRGenPass, <>node: uni.Name) -> None;
    def exit_int(self: DocIRGenPass, <>node: uni.Int) -> None;
    def exit_builtin_type(self: DocIRGenPass, <>node: uni.BuiltinType) -> None;
    def exit_float(self: DocIRGenPass, <>node: uni.Float) -> None;
    def exit_string(self: DocIRGenPass, <>node: uni.String) -> None;
    def exit_special_var_ref(self: DocIRGenPass, <>node: uni.SpecialVarRef) -> None;
    def exit_bool(self: DocIRGenPass, <>node: uni.Bool) -> None;
    def exit_null(self: DocIRGenPass, <>node: uni.Null) -> None;
    def exit_ellipsis(self: DocIRGenPass, <>node: uni.Ellipsis) -> None;
    def _jsx_attrs_need_multiline(self: DocIRGenPass, <>node: uni.JsxElement) -> bool;
    def exit_jsx_element(self: DocIRGenPass, <>node: uni.JsxElement) -> None;
    def exit_jsx_element_name(self: DocIRGenPass, <>node: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(
        self: DocIRGenPass, <>node: uni.JsxSpreadAttribute
    ) -> None;

    def exit_jsx_normal_attribute(
        self: DocIRGenPass, <>node: uni.JsxNormalAttribute
    ) -> None;

    def exit_jsx_text(self: DocIRGenPass, <>node: uni.JsxText) -> None;
    def exit_jsx_expression(self: DocIRGenPass, <>node: uni.JsxExpression) -> None;
}
