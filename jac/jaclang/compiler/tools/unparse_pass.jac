import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes { UniPass }
import from jaclang.compiler.frontend.constant { OwnershipKind, is_mut_kind }
import from jaclang.compiler.frontend.roles { BodyRole }

walker UnparsePass(UniPass) {
    def _comma_sep(nodes: Sequence[uni.UniNode]) -> str;
    can unparse_prepare_exit with uni.UniNode exit;
    can unparse_default_exit with uni.UniNode exit;
    can exit_token with uni.Token exit;
    can exit_name with uni.Name exit;
    can exit_string with uni.String exit;
    can exit_semi with uni.Semi exit;
    can exit_int with uni.Int exit;
    can exit_float with uni.Float exit;
    can exit_bool with uni.Bool exit;
    can exit_null with uni.Null exit;
    can exit_ellipsis with uni.Ellipsis exit;
    can exit_builtin_type with uni.BuiltinType exit;
    can exit_special_var_ref with uni.SpecialVarRef exit;
    can exit_module with uni.Module exit;
    can exit_sub_tag with uni.SubTag exit;
    can exit_type_alias with uni.TypeAlias exit;
    can exit_type_param with uni.TypeParam exit;
    can exit_global_vars with uni.GlobalVars exit;
    can exit_test with uni.Test exit;
    can exit_module_code with uni.ModuleCode exit;
    can exit_py_inline_code with uni.PyInlineCode exit;
    can exit_import with uni.Import exit;
    can exit_module_path with uni.ModulePath exit;
    can exit_module_item with uni.ModuleItem exit;
    can exit_archetype with uni.Archetype exit;
    can exit_impl_def with uni.ImplDef exit;
    can exit_sem_def with uni.SemDef exit;
    can exit_enum with uni.Enum exit;
    can exit_ability with uni.Ability exit;
    can exit_func_signature with uni.FuncSignature exit;
    can exit_event_signature with uni.EventSignature exit;
    can exit_param_var with uni.ParamVar exit;
    can exit_arch_has with uni.ArchHas exit;
    can exit_has_var with uni.HasVar exit;
    can exit_typed_ctx_block with uni.TypedCtxBlock exit;
    can exit_open_stmt with uni.OpenStmt exit;
    can exit_if_stmt with uni.IfStmt exit;
    can exit_else_if with uni.ElseIf exit;
    can exit_else_stmt with uni.ElseStmt exit;
    can exit_expr_stmt with uni.ExprStmt exit;
    can exit_try_stmt with uni.TryStmt exit;
    can exit_except with uni.Except exit;
    can exit_finally_stmt with uni.FinallyStmt exit;
    can exit_iter_for_stmt with uni.IterForStmt exit;
    can exit_in_for_stmt with uni.InForStmt exit;
    can exit_while_stmt with uni.WhileStmt exit;
    can exit_forever_stmt with uni.ForeverStmt exit;
    can exit_with_stmt with uni.WithStmt exit;
    can exit_expr_as_item with uni.ExprAsItem exit;
    can exit_raise_stmt with uni.RaiseStmt exit;
    can exit_assert_stmt with uni.AssertStmt exit;
    can exit_ctrl_stmt with uni.CtrlStmt exit;
    can exit_delete_stmt with uni.DeleteStmt exit;
    can exit_report_stmt with uni.ReportStmt exit;
    can exit_return_stmt with uni.ReturnStmt exit;
    can exit_visit_stmt with uni.VisitStmt exit;
    can exit_disengage_stmt with uni.DisengageStmt exit;
    can exit_await_expr with uni.AwaitExpr exit;
    can exit_cast_expr with uni.CastExpr exit;
    can exit_assignment with uni.Assignment exit;
    can exit_concurrent_expr with uni.ConcurrentExpr exit;
    can exit_binary_expr with uni.BinaryExpr exit;
    can exit_compare_expr with uni.CompareExpr exit;
    can exit_cfg_expr with uni.CfgExpr exit;
    can exit_bool_expr with uni.BoolExpr exit;
    can exit_lambda_expr with uni.LambdaExpr exit;
    can exit_unary_expr with uni.UnaryExpr exit;
    can exit_if_else_expr with uni.IfElseExpr exit;
    can exit_multi_string with uni.MultiString exit;
    can exit_f_string with uni.FString exit;
    can exit_formatted_value with uni.FormattedValue exit;
    can exit_list_val with uni.ListVal exit;
    can exit_set_val with uni.SetVal exit;
    can exit_tuple_val with uni.TupleVal exit;
    can exit_dict_val with uni.DictVal exit;
    can exit_k_v_pair with uni.KVPair exit;
    can exit_k_w_pair with uni.KWPair exit;
    can exit_inner_compr with uni.InnerCompr exit;
    can exit_list_compr with uni.ListCompr exit;
    can exit_gen_compr with uni.GenCompr exit;
    can exit_set_compr with uni.SetCompr exit;
    can exit_dict_compr with uni.DictCompr exit;
    can exit_atom_trailer with uni.AtomTrailer exit;
    can exit_atom_unit with uni.AtomUnit exit;
    can exit_graph_expr with uni.GraphExpr exit;
    can exit_yield_expr with uni.YieldExpr exit;
    can exit_func_call with uni.FuncCall exit;
    can exit_index_slice with uni.IndexSlice exit;
    can exit_edge_ref_trailer with uni.EdgeRefTrailer exit;
    can exit_edge_op_ref with uni.EdgeOpRef exit;
    can exit_disconnect_op with uni.DisconnectOp exit;
    can exit_connect_op with uni.ConnectOp exit;
    can exit_filter_compr with uni.FilterCompr exit;
    can exit_assign_compr with uni.AssignCompr exit;
    can exit_jsx_element with uni.JsxElement exit;
    can exit_jsx_element_name with uni.JsxElementName exit;
    can exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit;
    can exit_jsx_normal_attribute with uni.JsxNormalAttribute exit;
    can exit_jsx_text with uni.JsxText exit;
    can exit_jsx_expression with uni.JsxExpression exit;
    can exit_jsx_slot with uni.JsxSlot exit;
    can exit_jsx_comment with uni.JsxComment exit;
    can exit_match_stmt with uni.MatchStmt exit;
    can exit_match_case with uni.MatchCase exit;
    can exit_switch_stmt with uni.SwitchStmt exit;
    can exit_switch_case with uni.SwitchCase exit;
    can exit_match_or with uni.MatchOr exit;
    can exit_match_as with uni.MatchAs exit;
    can exit_match_wild with uni.MatchWild exit;
    can exit_match_value with uni.MatchValue exit;
    can exit_match_singleton with uni.MatchSingleton exit;
    can exit_match_sequence with uni.MatchSequence exit;
    can exit_match_mapping with uni.MatchMapping exit;
    can exit_match_k_v_pair with uni.MatchKVPair exit;
    can exit_match_star with uni.MatchStar exit;
    can exit_match_arch with uni.MatchArch exit;
}

def unparse_node(nd: uni.UniNode) -> str {
    if nd.gen.jac {
        return nd.gen.jac;
    }
    if isinstance(nd, uni.Token) {
        return nd.value;
    }
    _kids = list(nd.kid);
    if not _kids {
        _v = nd?.value;
        if isinstance(_v, str) {
            return _v;
        }
    }
    return ' '.join([unparse_node(i) for i in _kids]);
}

def unparse_module(mod: uni.Module, requires_format: bool = True) -> str {
    import from jaclang.compiler.tools.jac_formatter_pass { format_module }
    import from jaclang.compiler.tools.normalize_pass { NormalizePass }
    import from jaclang.compiler.driver.program { JacProgram }

    own_path = mod.loc.mod_path;
    saved_body = mod.body;
    saved_kid = mod.kid;
    head_kid = [
        k
        for k in saved_kid
        if (not k.loc.mod_path) or (k.loc.mod_path == own_path)
    ];
    filtered = len(head_kid) != len(saved_kid);

    with mod.structure_thawed() {
        if filtered {
            mod._role_set(
                BodyRole,
                [
                    st
                    for st in saved_body
                    if (not st.loc.mod_path) or (st.loc.mod_path == own_path)
                ]
            );
            mod.set_kids(nodes=head_kid or [uni.EmptyToken()]);
        }
        try {
            import from jaclang.compiler.driver.pipeline { run_utility, UtilityProduct }
            run_utility(UtilityProduct.NORMALIZE, mod, JacProgram());
            if requires_format {
                return format_module(mod);
            }
            run_utility(UtilityProduct.UNPARSE, mod, JacProgram());
            return mod.gen.jac;
        } finally {
            if filtered {
                mod._role_set(BodyRole, saved_body);
                mod.set_kids(nodes=saved_kid);
            }
        }
    }
}
