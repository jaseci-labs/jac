"""Auto-generated visitor accept overrides (#6942 A.1).

DO NOT EDIT MANUALLY - regenerate with `jac gen-uni-dispatch`.
"""

impl Ability.accept_enter(v: UniPass) -> None {
    v.enter_ability(self);
}

impl ArchHas.accept_enter(v: UniPass) -> None {
    v.enter_arch_has(self);
}

impl Archetype.accept_enter(v: UniPass) -> None {
    v.enter_archetype(self);
}

impl AssertStmt.accept_enter(v: UniPass) -> None {
    v.enter_assert_stmt(self);
}

impl AssignCompr.accept_enter(v: UniPass) -> None {
    v.enter_assign_compr(self);
}

impl Assignment.accept_enter(v: UniPass) -> None {
    v.enter_assignment(self);
}

impl AtomTrailer.accept_enter(v: UniPass) -> None {
    v.enter_atom_trailer(self);
}

impl AtomUnit.accept_enter(v: UniPass) -> None {
    v.enter_atom_unit(self);
}

impl AwaitExpr.accept_enter(v: UniPass) -> None {
    v.enter_await_expr(self);
}

impl AwaitingClause.accept_enter(v: UniPass) -> None {
    v.enter_awaiting_clause(self);
}

impl BinaryExpr.accept_enter(v: UniPass) -> None {
    v.enter_binary_expr(self);
}

impl BoolExpr.accept_enter(v: UniPass) -> None {
    v.enter_bool_expr(self);
}

impl BuiltinType.accept_enter(v: UniPass) -> None {
    v.enter_builtin_type(self);
}

impl CastExpr.accept_enter(v: UniPass) -> None {
    v.enter_cast_expr(self);
}

impl CfgExpr.accept_enter(v: UniPass) -> None {
    v.enter_cfg_expr(self);
}

impl ClientBlock.accept_enter(v: UniPass) -> None {
    v.enter_client_block(self);
}

impl CompareExpr.accept_enter(v: UniPass) -> None {
    v.enter_compare_expr(self);
}

impl ConcurrentExpr.accept_enter(v: UniPass) -> None {
    v.enter_concurrent_expr(self);
}

impl ConnectOp.accept_enter(v: UniPass) -> None {
    v.enter_connect_op(self);
}

impl CtrlStmt.accept_enter(v: UniPass) -> None {
    v.enter_ctrl_stmt(self);
}

impl DeleteStmt.accept_enter(v: UniPass) -> None {
    v.enter_delete_stmt(self);
}

impl DictCompr.accept_enter(v: UniPass) -> None {
    v.enter_dict_compr(self);
}

impl DictVal.accept_enter(v: UniPass) -> None {
    v.enter_dict_val(self);
}

impl DisconnectOp.accept_enter(v: UniPass) -> None {
    v.enter_disconnect_op(self);
}

impl DisengageStmt.accept_enter(v: UniPass) -> None {
    v.enter_disengage_stmt(self);
}

impl EdgeOpRef.accept_enter(v: UniPass) -> None {
    v.enter_edge_op_ref(self);
}

impl EdgeRefTrailer.accept_enter(v: UniPass) -> None {
    v.enter_edge_ref_trailer(self);
}

impl ElseIf.accept_enter(v: UniPass) -> None {
    v.enter_else_if(self);
}

impl ElseStmt.accept_enter(v: UniPass) -> None {
    v.enter_else_stmt(self);
}

impl Enum.accept_enter(v: UniPass) -> None {
    v.enter_enum(self);
}

impl EventSignature.accept_enter(v: UniPass) -> None {
    v.enter_event_signature(self);
}

impl Except.accept_enter(v: UniPass) -> None {
    v.enter_except(self);
}

impl ExprAsItem.accept_enter(v: UniPass) -> None {
    v.enter_expr_as_item(self);
}

impl ExprStmt.accept_enter(v: UniPass) -> None {
    v.enter_expr_stmt(self);
}

impl FString.accept_enter(v: UniPass) -> None {
    v.enter_f_string(self);
}

impl FilterCompr.accept_enter(v: UniPass) -> None {
    v.enter_filter_compr(self);
}

impl FinallyStmt.accept_enter(v: UniPass) -> None {
    v.enter_finally_stmt(self);
}

impl FormattedValue.accept_enter(v: UniPass) -> None {
    v.enter_formatted_value(self);
}

impl FuncCall.accept_enter(v: UniPass) -> None {
    v.enter_func_call(self);
}

impl FuncSignature.accept_enter(v: UniPass) -> None {
    v.enter_func_signature(self);
}

impl GenCompr.accept_enter(v: UniPass) -> None {
    v.enter_gen_compr(self);
}

impl GlobalStmt.accept_enter(v: UniPass) -> None {
    v.enter_global_stmt(self);
}

impl GlobalVars.accept_enter(v: UniPass) -> None {
    v.enter_global_vars(self);
}

impl HasVar.accept_enter(v: UniPass) -> None {
    v.enter_has_var(self);
}

impl IfElseExpr.accept_enter(v: UniPass) -> None {
    v.enter_if_else_expr(self);
}

impl IfStmt.accept_enter(v: UniPass) -> None {
    v.enter_if_stmt(self);
}

impl ImplDef.accept_enter(v: UniPass) -> None {
    v.enter_impl_def(self);
}

impl Import.accept_enter(v: UniPass) -> None {
    v.enter_import(self);
}

impl InForStmt.accept_enter(v: UniPass) -> None {
    v.enter_in_for_stmt(self);
}

impl IndexSlice.accept_enter(v: UniPass) -> None {
    v.enter_index_slice(self);
}

impl InnerCompr.accept_enter(v: UniPass) -> None {
    v.enter_inner_compr(self);
}

impl IterForStmt.accept_enter(v: UniPass) -> None {
    v.enter_iter_for_stmt(self);
}

impl JsxAttribute.accept_enter(v: UniPass) -> None {
    v.enter_jsx_attribute(self);
}

impl JsxChild.accept_enter(v: UniPass) -> None {
    v.enter_jsx_child(self);
}

impl JsxComment.accept_enter(v: UniPass) -> None {
    v.enter_jsx_comment(self);
}

impl JsxElement.accept_enter(v: UniPass) -> None {
    v.enter_jsx_element(self);
}

impl JsxElementName.accept_enter(v: UniPass) -> None {
    v.enter_jsx_element_name(self);
}

impl JsxExpression.accept_enter(v: UniPass) -> None {
    v.enter_jsx_expression(self);
}

impl JsxNormalAttribute.accept_enter(v: UniPass) -> None {
    v.enter_jsx_normal_attribute(self);
}

impl JsxSlot.accept_enter(v: UniPass) -> None {
    v.enter_jsx_slot(self);
}

impl JsxSpreadAttribute.accept_enter(v: UniPass) -> None {
    v.enter_jsx_spread_attribute(self);
}

impl JsxText.accept_enter(v: UniPass) -> None {
    v.enter_jsx_text(self);
}

impl KVPair.accept_enter(v: UniPass) -> None {
    v.enter_k_v_pair(self);
}

impl KWPair.accept_enter(v: UniPass) -> None {
    v.enter_k_w_pair(self);
}

impl LambdaExpr.accept_enter(v: UniPass) -> None {
    v.enter_lambda_expr(self);
}

impl ListCompr.accept_enter(v: UniPass) -> None {
    v.enter_list_compr(self);
}

impl ListVal.accept_enter(v: UniPass) -> None {
    v.enter_list_val(self);
}

impl MatchArch.accept_enter(v: UniPass) -> None {
    v.enter_match_arch(self);
}

impl MatchAs.accept_enter(v: UniPass) -> None {
    v.enter_match_as(self);
}

impl MatchCase.accept_enter(v: UniPass) -> None {
    v.enter_match_case(self);
}

impl MatchKVPair.accept_enter(v: UniPass) -> None {
    v.enter_match_k_v_pair(self);
}

impl MatchMapping.accept_enter(v: UniPass) -> None {
    v.enter_match_mapping(self);
}

impl MatchOr.accept_enter(v: UniPass) -> None {
    v.enter_match_or(self);
}

impl MatchSequence.accept_enter(v: UniPass) -> None {
    v.enter_match_sequence(self);
}

impl MatchSingleton.accept_enter(v: UniPass) -> None {
    v.enter_match_singleton(self);
}

impl MatchStar.accept_enter(v: UniPass) -> None {
    v.enter_match_star(self);
}

impl MatchStmt.accept_enter(v: UniPass) -> None {
    v.enter_match_stmt(self);
}

impl MatchValue.accept_enter(v: UniPass) -> None {
    v.enter_match_value(self);
}

impl MatchWild.accept_enter(v: UniPass) -> None {
    v.enter_match_wild(self);
}

impl Module.accept_enter(v: UniPass) -> None {
    v.enter_module(self);
}

impl ModuleCode.accept_enter(v: UniPass) -> None {
    v.enter_module_code(self);
}

impl ModuleItem.accept_enter(v: UniPass) -> None {
    v.enter_module_item(self);
}

impl ModulePath.accept_enter(v: UniPass) -> None {
    v.enter_module_path(self);
}

impl MultiString.accept_enter(v: UniPass) -> None {
    v.enter_multi_string(self);
}

impl Name.accept_enter(v: UniPass) -> None {
    v.enter_name(self);
}

impl NativeBlock.accept_enter(v: UniPass) -> None {
    v.enter_native_block(self);
}

impl NonLocalStmt.accept_enter(v: UniPass) -> None {
    v.enter_non_local_stmt(self);
}

impl ParamVar.accept_enter(v: UniPass) -> None {
    v.enter_param_var(self);
}

impl PyInlineCode.accept_enter(v: UniPass) -> None {
    v.enter_py_inline_code(self);
}

impl RaiseStmt.accept_enter(v: UniPass) -> None {
    v.enter_raise_stmt(self);
}

impl ReportStmt.accept_enter(v: UniPass) -> None {
    v.enter_report_stmt(self);
}

impl ReturnStmt.accept_enter(v: UniPass) -> None {
    v.enter_return_stmt(self);
}

impl SemDef.accept_enter(v: UniPass) -> None {
    v.enter_sem_def(self);
}

impl ServerBlock.accept_enter(v: UniPass) -> None {
    v.enter_server_block(self);
}

impl SetCompr.accept_enter(v: UniPass) -> None {
    v.enter_set_compr(self);
}

impl SetVal.accept_enter(v: UniPass) -> None {
    v.enter_set_val(self);
}

impl Slice.accept_enter(v: UniPass) -> None {
    v.enter_slice(self);
}

impl SpecialVarRef.accept_enter(v: UniPass) -> None {
    v.enter_special_var_ref(self);
}

impl String.accept_enter(v: UniPass) -> None {
    v.enter_string(self);
}

impl SubTag.accept_enter(v: UniPass) -> None {
    v.enter_sub_tag(self);
}

impl SwitchCase.accept_enter(v: UniPass) -> None {
    v.enter_switch_case(self);
}

impl SwitchStmt.accept_enter(v: UniPass) -> None {
    v.enter_switch_stmt(self);
}

impl Test.accept_enter(v: UniPass) -> None {
    v.enter_test(self);
}

impl Token.accept_enter(v: UniPass) -> None {
    v.enter_token(self);
}

impl TryStmt.accept_enter(v: UniPass) -> None {
    v.enter_try_stmt(self);
}

impl TupleVal.accept_enter(v: UniPass) -> None {
    v.enter_tuple_val(self);
}

impl TypeAlias.accept_enter(v: UniPass) -> None {
    v.enter_type_alias(self);
}

impl TypeParam.accept_enter(v: UniPass) -> None {
    v.enter_type_param(self);
}

impl TypedCtxBlock.accept_enter(v: UniPass) -> None {
    v.enter_typed_ctx_block(self);
}

impl UnaryExpr.accept_enter(v: UniPass) -> None {
    v.enter_unary_expr(self);
}

impl VisitStmt.accept_enter(v: UniPass) -> None {
    v.enter_visit_stmt(self);
}

impl WhileStmt.accept_enter(v: UniPass) -> None {
    v.enter_while_stmt(self);
}

impl WithStmt.accept_enter(v: UniPass) -> None {
    v.enter_with_stmt(self);
}

impl YieldExpr.accept_enter(v: UniPass) -> None {
    v.enter_yield_expr(self);
}

impl Ability.accept_exit(v: UniPass) -> None {
    v.exit_ability(self);
}

impl ArchHas.accept_exit(v: UniPass) -> None {
    v.exit_arch_has(self);
}

impl Archetype.accept_exit(v: UniPass) -> None {
    v.exit_archetype(self);
}

impl AssertStmt.accept_exit(v: UniPass) -> None {
    v.exit_assert_stmt(self);
}

impl AssignCompr.accept_exit(v: UniPass) -> None {
    v.exit_assign_compr(self);
}

impl Assignment.accept_exit(v: UniPass) -> None {
    v.exit_assignment(self);
}

impl AtomTrailer.accept_exit(v: UniPass) -> None {
    v.exit_atom_trailer(self);
}

impl AtomUnit.accept_exit(v: UniPass) -> None {
    v.exit_atom_unit(self);
}

impl AwaitExpr.accept_exit(v: UniPass) -> None {
    v.exit_await_expr(self);
}

impl AwaitingClause.accept_exit(v: UniPass) -> None {
    v.exit_awaiting_clause(self);
}

impl BinaryExpr.accept_exit(v: UniPass) -> None {
    v.exit_binary_expr(self);
}

impl Bool.accept_exit(v: UniPass) -> None {
    v.exit_bool(self);
}

impl BoolExpr.accept_exit(v: UniPass) -> None {
    v.exit_bool_expr(self);
}

impl BuiltinType.accept_exit(v: UniPass) -> None {
    v.exit_builtin_type(self);
}

impl CastExpr.accept_exit(v: UniPass) -> None {
    v.exit_cast_expr(self);
}

impl CfgExpr.accept_exit(v: UniPass) -> None {
    v.exit_cfg_expr(self);
}

impl ClientBlock.accept_exit(v: UniPass) -> None {
    v.exit_client_block(self);
}

impl CommentToken.accept_exit(v: UniPass) -> None {
    v.exit_comment_token(self);
}

impl CompareExpr.accept_exit(v: UniPass) -> None {
    v.exit_compare_expr(self);
}

impl ConcurrentExpr.accept_exit(v: UniPass) -> None {
    v.exit_concurrent_expr(self);
}

impl ConnectOp.accept_exit(v: UniPass) -> None {
    v.exit_connect_op(self);
}

impl CtrlStmt.accept_exit(v: UniPass) -> None {
    v.exit_ctrl_stmt(self);
}

impl DeleteStmt.accept_exit(v: UniPass) -> None {
    v.exit_delete_stmt(self);
}

impl DictCompr.accept_exit(v: UniPass) -> None {
    v.exit_dict_compr(self);
}

impl DictVal.accept_exit(v: UniPass) -> None {
    v.exit_dict_val(self);
}

impl DisconnectOp.accept_exit(v: UniPass) -> None {
    v.exit_disconnect_op(self);
}

impl DisengageStmt.accept_exit(v: UniPass) -> None {
    v.exit_disengage_stmt(self);
}

impl EdgeOpRef.accept_exit(v: UniPass) -> None {
    v.exit_edge_op_ref(self);
}

impl EdgeRefTrailer.accept_exit(v: UniPass) -> None {
    v.exit_edge_ref_trailer(self);
}

impl Ellipsis.accept_exit(v: UniPass) -> None {
    v.exit_ellipsis(self);
}

impl ElseIf.accept_exit(v: UniPass) -> None {
    v.exit_else_if(self);
}

impl ElseStmt.accept_exit(v: UniPass) -> None {
    v.exit_else_stmt(self);
}

impl Enum.accept_exit(v: UniPass) -> None {
    v.exit_enum(self);
}

impl EventSignature.accept_exit(v: UniPass) -> None {
    v.exit_event_signature(self);
}

impl Except.accept_exit(v: UniPass) -> None {
    v.exit_except(self);
}

impl ExprAsItem.accept_exit(v: UniPass) -> None {
    v.exit_expr_as_item(self);
}

impl ExprStmt.accept_exit(v: UniPass) -> None {
    v.exit_expr_stmt(self);
}

impl FString.accept_exit(v: UniPass) -> None {
    v.exit_f_string(self);
}

impl FilterCompr.accept_exit(v: UniPass) -> None {
    v.exit_filter_compr(self);
}

impl FinallyStmt.accept_exit(v: UniPass) -> None {
    v.exit_finally_stmt(self);
}

impl Float.accept_exit(v: UniPass) -> None {
    v.exit_float(self);
}

impl FormattedValue.accept_exit(v: UniPass) -> None {
    v.exit_formatted_value(self);
}

impl FuncCall.accept_exit(v: UniPass) -> None {
    v.exit_func_call(self);
}

impl FuncSignature.accept_exit(v: UniPass) -> None {
    v.exit_func_signature(self);
}

impl GenCompr.accept_exit(v: UniPass) -> None {
    v.exit_gen_compr(self);
}

impl GlobalStmt.accept_exit(v: UniPass) -> None {
    v.exit_global_stmt(self);
}

impl GlobalVars.accept_exit(v: UniPass) -> None {
    v.exit_global_vars(self);
}

impl HasVar.accept_exit(v: UniPass) -> None {
    v.exit_has_var(self);
}

impl IfElseExpr.accept_exit(v: UniPass) -> None {
    v.exit_if_else_expr(self);
}

impl IfStmt.accept_exit(v: UniPass) -> None {
    v.exit_if_stmt(self);
}

impl ImplDef.accept_exit(v: UniPass) -> None {
    v.exit_impl_def(self);
}

impl Import.accept_exit(v: UniPass) -> None {
    v.exit_import(self);
}

impl InForStmt.accept_exit(v: UniPass) -> None {
    v.exit_in_for_stmt(self);
}

impl IndexSlice.accept_exit(v: UniPass) -> None {
    v.exit_index_slice(self);
}

impl InnerCompr.accept_exit(v: UniPass) -> None {
    v.exit_inner_compr(self);
}

impl Int.accept_exit(v: UniPass) -> None {
    v.exit_int(self);
}

impl IterForStmt.accept_exit(v: UniPass) -> None {
    v.exit_iter_for_stmt(self);
}

impl JsxAttribute.accept_exit(v: UniPass) -> None {
    v.exit_jsx_attribute(self);
}

impl JsxChild.accept_exit(v: UniPass) -> None {
    v.exit_jsx_child(self);
}

impl JsxComment.accept_exit(v: UniPass) -> None {
    v.exit_jsx_comment(self);
}

impl JsxElement.accept_exit(v: UniPass) -> None {
    v.exit_jsx_element(self);
}

impl JsxElementName.accept_exit(v: UniPass) -> None {
    v.exit_jsx_element_name(self);
}

impl JsxExpression.accept_exit(v: UniPass) -> None {
    v.exit_jsx_expression(self);
}

impl JsxNormalAttribute.accept_exit(v: UniPass) -> None {
    v.exit_jsx_normal_attribute(self);
}

impl JsxSlot.accept_exit(v: UniPass) -> None {
    v.exit_jsx_slot(self);
}

impl JsxSpreadAttribute.accept_exit(v: UniPass) -> None {
    v.exit_jsx_spread_attribute(self);
}

impl JsxText.accept_exit(v: UniPass) -> None {
    v.exit_jsx_text(self);
}

impl KVPair.accept_exit(v: UniPass) -> None {
    v.exit_k_v_pair(self);
}

impl KWPair.accept_exit(v: UniPass) -> None {
    v.exit_k_w_pair(self);
}

impl LambdaExpr.accept_exit(v: UniPass) -> None {
    v.exit_lambda_expr(self);
}

impl ListCompr.accept_exit(v: UniPass) -> None {
    v.exit_list_compr(self);
}

impl ListVal.accept_exit(v: UniPass) -> None {
    v.exit_list_val(self);
}

impl MatchArch.accept_exit(v: UniPass) -> None {
    v.exit_match_arch(self);
}

impl MatchAs.accept_exit(v: UniPass) -> None {
    v.exit_match_as(self);
}

impl MatchCase.accept_exit(v: UniPass) -> None {
    v.exit_match_case(self);
}

impl MatchKVPair.accept_exit(v: UniPass) -> None {
    v.exit_match_k_v_pair(self);
}

impl MatchMapping.accept_exit(v: UniPass) -> None {
    v.exit_match_mapping(self);
}

impl MatchOr.accept_exit(v: UniPass) -> None {
    v.exit_match_or(self);
}

impl MatchSequence.accept_exit(v: UniPass) -> None {
    v.exit_match_sequence(self);
}

impl MatchSingleton.accept_exit(v: UniPass) -> None {
    v.exit_match_singleton(self);
}

impl MatchStar.accept_exit(v: UniPass) -> None {
    v.exit_match_star(self);
}

impl MatchStmt.accept_exit(v: UniPass) -> None {
    v.exit_match_stmt(self);
}

impl MatchValue.accept_exit(v: UniPass) -> None {
    v.exit_match_value(self);
}

impl MatchWild.accept_exit(v: UniPass) -> None {
    v.exit_match_wild(self);
}

impl Module.accept_exit(v: UniPass) -> None {
    v.exit_module(self);
}

impl ModuleCode.accept_exit(v: UniPass) -> None {
    v.exit_module_code(self);
}

impl ModuleItem.accept_exit(v: UniPass) -> None {
    v.exit_module_item(self);
}

impl ModulePath.accept_exit(v: UniPass) -> None {
    v.exit_module_path(self);
}

impl MultiString.accept_exit(v: UniPass) -> None {
    v.exit_multi_string(self);
}

impl Name.accept_exit(v: UniPass) -> None {
    v.exit_name(self);
}

impl NativeBlock.accept_exit(v: UniPass) -> None {
    v.exit_native_block(self);
}

impl NonLocalStmt.accept_exit(v: UniPass) -> None {
    v.exit_non_local_stmt(self);
}

impl Null.accept_exit(v: UniPass) -> None {
    v.exit_null(self);
}

impl ParamVar.accept_exit(v: UniPass) -> None {
    v.exit_param_var(self);
}

impl PyInlineCode.accept_exit(v: UniPass) -> None {
    v.exit_py_inline_code(self);
}

impl RaiseStmt.accept_exit(v: UniPass) -> None {
    v.exit_raise_stmt(self);
}

impl ReportStmt.accept_exit(v: UniPass) -> None {
    v.exit_report_stmt(self);
}

impl ReturnStmt.accept_exit(v: UniPass) -> None {
    v.exit_return_stmt(self);
}

impl SemDef.accept_exit(v: UniPass) -> None {
    v.exit_sem_def(self);
}

impl Semi.accept_exit(v: UniPass) -> None {
    v.exit_semi(self);
}

impl ServerBlock.accept_exit(v: UniPass) -> None {
    v.exit_server_block(self);
}

impl SetCompr.accept_exit(v: UniPass) -> None {
    v.exit_set_compr(self);
}

impl SetVal.accept_exit(v: UniPass) -> None {
    v.exit_set_val(self);
}

impl Slice.accept_exit(v: UniPass) -> None {
    v.exit_slice(self);
}

impl SpecialVarRef.accept_exit(v: UniPass) -> None {
    v.exit_special_var_ref(self);
}

impl String.accept_exit(v: UniPass) -> None {
    v.exit_string(self);
}

impl SubTag.accept_exit(v: UniPass) -> None {
    v.exit_sub_tag(self);
}

impl SwitchCase.accept_exit(v: UniPass) -> None {
    v.exit_switch_case(self);
}

impl SwitchStmt.accept_exit(v: UniPass) -> None {
    v.exit_switch_stmt(self);
}

impl Test.accept_exit(v: UniPass) -> None {
    v.exit_test(self);
}

impl Token.accept_exit(v: UniPass) -> None {
    v.exit_token(self);
}

impl TryStmt.accept_exit(v: UniPass) -> None {
    v.exit_try_stmt(self);
}

impl TupleVal.accept_exit(v: UniPass) -> None {
    v.exit_tuple_val(self);
}

impl TypeAlias.accept_exit(v: UniPass) -> None {
    v.exit_type_alias(self);
}

impl TypeParam.accept_exit(v: UniPass) -> None {
    v.exit_type_param(self);
}

impl TypedCtxBlock.accept_exit(v: UniPass) -> None {
    v.exit_typed_ctx_block(self);
}

impl UnaryExpr.accept_exit(v: UniPass) -> None {
    v.exit_unary_expr(self);
}

impl VisitStmt.accept_exit(v: UniPass) -> None {
    v.exit_visit_stmt(self);
}

impl WhileStmt.accept_exit(v: UniPass) -> None {
    v.exit_while_stmt(self);
}

impl WithStmt.accept_exit(v: UniPass) -> None {
    v.exit_with_stmt(self);
}

impl YieldExpr.accept_exit(v: UniPass) -> None {
    v.exit_yield_expr(self);
}
