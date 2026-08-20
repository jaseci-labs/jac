import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    AwaitingClause,
    BinaryExpr,
    Bool,
    BoolExpr,
    BuiltinType,
    CastExpr,
    CfgExpr,
    CommentToken,
    CompareExpr,
    ConcurrentExpr,
    ConnectOp,
    CtrlStmt,
    DeleteStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    Ellipsis,
    ElseIf,
    ElseStmt,
    Enum,
    EventSignature,
    Except,
    ExprAsItem,
    ExprStmt,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    GlobalVars,
    HasVar,
    IfElseExpr,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    InnerCompr,
    Int,
    IterForStmt,
    JsxAttribute,
    JsxChild,
    JsxComment,
    JsxElement,
    JsxElementName,
    JsxExpression,
    JsxNormalAttribute,
    JsxSlot,
    JsxSpreadAttribute,
    JsxText,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchKVPair,
    MatchMapping,
    MatchOr,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchStmt,
    MatchValue,
    MatchWild,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    Null,
    OpenStmt,
    ParamVar,
    PyInlineCode,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SetVal,
    Slice,
    SpecialVarRef,
    String,
    SubTag,
    SwitchCase,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TupleVal,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    UniNode,
    VisitStmt,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }

obj UniPass(ModuleCodegenPass) {
    has term_signal: bool = False,
        prune_signal: bool = False;

    def postinit -> None;
    def before_pass -> None;
    def after_pass -> None;
    def enter_node(nd: UniNode) -> None;
    def exit_node(nd: UniNode) -> None;
    def default_enter(nd: UniNode) -> None;
    def default_exit(nd: UniNode) -> None;
    def prune -> None;
    def recalculate_parents(nd: UniNode) -> None;
    def transform(ir_in: Module) -> Module;
    def traverse(nd: UniNode) -> UniNode;
    # >>> generated visitor surface (jac gen-uni-dispatch) >>>
    def enter_ability(nd: Ability) -> None;
    def enter_arch_has(nd: ArchHas) -> None;
    def enter_archetype(nd: Archetype) -> None;
    def enter_assert_stmt(nd: AssertStmt) -> None;
    def enter_assign_compr(nd: AssignCompr) -> None;
    def enter_assignment(nd: Assignment) -> None;
    def enter_atom_trailer(nd: AtomTrailer) -> None;
    def enter_atom_unit(nd: AtomUnit) -> None;
    def enter_await_expr(nd: AwaitExpr) -> None;
    def enter_awaiting_clause(nd: AwaitingClause) -> None;
    def enter_binary_expr(nd: BinaryExpr) -> None;
    def enter_bool_expr(nd: BoolExpr) -> None;
    def enter_builtin_type(nd: BuiltinType) -> None;
    def enter_cast_expr(nd: CastExpr) -> None;
    def enter_cfg_expr(nd: CfgExpr) -> None;
    def enter_compare_expr(nd: CompareExpr) -> None;
    def enter_concurrent_expr(nd: ConcurrentExpr) -> None;
    def enter_connect_op(nd: ConnectOp) -> None;
    def enter_ctrl_stmt(nd: CtrlStmt) -> None;
    def enter_delete_stmt(nd: DeleteStmt) -> None;
    def enter_dict_compr(nd: DictCompr) -> None;
    def enter_dict_val(nd: DictVal) -> None;
    def enter_disconnect_op(nd: DisconnectOp) -> None;
    def enter_disengage_stmt(nd: DisengageStmt) -> None;
    def enter_edge_op_ref(nd: EdgeOpRef) -> None;
    def enter_edge_ref_trailer(nd: EdgeRefTrailer) -> None;
    def enter_else_if(nd: ElseIf) -> None;
    def enter_else_stmt(nd: ElseStmt) -> None;
    def enter_enum(nd: Enum) -> None;
    def enter_event_signature(nd: EventSignature) -> None;
    def enter_except(nd: Except) -> None;
    def enter_expr_as_item(nd: ExprAsItem) -> None;
    def enter_expr_stmt(nd: ExprStmt) -> None;
    def enter_f_string(nd: FString) -> None;
    def enter_filter_compr(nd: FilterCompr) -> None;
    def enter_finally_stmt(nd: FinallyStmt) -> None;
    def enter_forever_stmt(nd: ForeverStmt) -> None;
    def enter_formatted_value(nd: FormattedValue) -> None;
    def enter_func_call(nd: FuncCall) -> None;
    def enter_func_signature(nd: FuncSignature) -> None;
    def enter_gen_compr(nd: GenCompr) -> None;
    def enter_global_vars(nd: GlobalVars) -> None;
    def enter_has_var(nd: HasVar) -> None;
    def enter_if_else_expr(nd: IfElseExpr) -> None;
    def enter_if_stmt(nd: IfStmt) -> None;
    def enter_impl_def(nd: ImplDef) -> None;
    def enter_import(nd: Import) -> None;
    def enter_in_for_stmt(nd: InForStmt) -> None;
    def enter_index_slice(nd: IndexSlice) -> None;
    def enter_inner_compr(nd: InnerCompr) -> None;
    def enter_iter_for_stmt(nd: IterForStmt) -> None;
    def enter_jsx_attribute(nd: JsxAttribute) -> None;
    def enter_jsx_child(nd: JsxChild) -> None;
    def enter_jsx_comment(nd: JsxComment) -> None;
    def enter_jsx_element(nd: JsxElement) -> None;
    def enter_jsx_element_name(nd: JsxElementName) -> None;
    def enter_jsx_expression(nd: JsxExpression) -> None;
    def enter_jsx_normal_attribute(nd: JsxNormalAttribute) -> None;
    def enter_jsx_slot(nd: JsxSlot) -> None;
    def enter_jsx_spread_attribute(nd: JsxSpreadAttribute) -> None;
    def enter_jsx_text(nd: JsxText) -> None;
    def enter_k_v_pair(nd: KVPair) -> None;
    def enter_k_w_pair(nd: KWPair) -> None;
    def enter_lambda_expr(nd: LambdaExpr) -> None;
    def enter_list_compr(nd: ListCompr) -> None;
    def enter_list_val(nd: ListVal) -> None;
    def enter_match_arch(nd: MatchArch) -> None;
    def enter_match_as(nd: MatchAs) -> None;
    def enter_match_case(nd: MatchCase) -> None;
    def enter_match_k_v_pair(nd: MatchKVPair) -> None;
    def enter_match_mapping(nd: MatchMapping) -> None;
    def enter_match_or(nd: MatchOr) -> None;
    def enter_match_sequence(nd: MatchSequence) -> None;
    def enter_match_singleton(nd: MatchSingleton) -> None;
    def enter_match_star(nd: MatchStar) -> None;
    def enter_match_stmt(nd: MatchStmt) -> None;
    def enter_match_value(nd: MatchValue) -> None;
    def enter_match_wild(nd: MatchWild) -> None;
    def enter_module(nd: Module) -> None;
    def enter_module_code(nd: ModuleCode) -> None;
    def enter_module_item(nd: ModuleItem) -> None;
    def enter_module_path(nd: ModulePath) -> None;
    def enter_multi_string(nd: MultiString) -> None;
    def enter_name(nd: Name) -> None;
    def enter_open_stmt(nd: OpenStmt) -> None;
    def enter_param_var(nd: ParamVar) -> None;
    def enter_py_inline_code(nd: PyInlineCode) -> None;
    def enter_raise_stmt(nd: RaiseStmt) -> None;
    def enter_report_stmt(nd: ReportStmt) -> None;
    def enter_return_stmt(nd: ReturnStmt) -> None;
    def enter_sem_def(nd: SemDef) -> None;
    def enter_set_compr(nd: SetCompr) -> None;
    def enter_set_val(nd: SetVal) -> None;
    def enter_slice(nd: Slice) -> None;
    def enter_special_var_ref(nd: SpecialVarRef) -> None;
    def enter_string(nd: String) -> None;
    def enter_sub_tag(nd: SubTag) -> None;
    def enter_switch_case(nd: SwitchCase) -> None;
    def enter_switch_stmt(nd: SwitchStmt) -> None;
    def enter_test(nd: Test) -> None;
    def enter_token(nd: Token) -> None;
    def enter_try_stmt(nd: TryStmt) -> None;
    def enter_tuple_val(nd: TupleVal) -> None;
    def enter_type_alias(nd: TypeAlias) -> None;
    def enter_type_param(nd: TypeParam) -> None;
    def enter_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def enter_unary_expr(nd: UnaryExpr) -> None;
    def enter_visit_stmt(nd: VisitStmt) -> None;
    def enter_while_stmt(nd: WhileStmt) -> None;
    def enter_with_stmt(nd: WithStmt) -> None;
    def enter_yield_expr(nd: YieldExpr) -> None;
    def exit_ability(nd: Ability) -> None;
    def exit_arch_has(nd: ArchHas) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def exit_assert_stmt(nd: AssertStmt) -> None;
    def exit_assign_compr(nd: AssignCompr) -> None;
    def exit_assignment(nd: Assignment) -> None;
    def exit_atom_trailer(nd: AtomTrailer) -> None;
    def exit_atom_unit(nd: AtomUnit) -> None;
    def exit_await_expr(nd: AwaitExpr) -> None;
    def exit_awaiting_clause(nd: AwaitingClause) -> None;
    def exit_binary_expr(nd: BinaryExpr) -> None;
    def exit_bool(nd: Bool) -> None;
    def exit_bool_expr(nd: BoolExpr) -> None;
    def exit_builtin_type(nd: BuiltinType) -> None;
    def exit_cast_expr(nd: CastExpr) -> None;
    def exit_cfg_expr(nd: CfgExpr) -> None;
    def exit_comment_token(nd: CommentToken) -> None;
    def exit_compare_expr(nd: CompareExpr) -> None;
    def exit_concurrent_expr(nd: ConcurrentExpr) -> None;
    def exit_connect_op(nd: ConnectOp) -> None;
    def exit_ctrl_stmt(nd: CtrlStmt) -> None;
    def exit_delete_stmt(nd: DeleteStmt) -> None;
    def exit_dict_compr(nd: DictCompr) -> None;
    def exit_dict_val(nd: DictVal) -> None;
    def exit_disconnect_op(nd: DisconnectOp) -> None;
    def exit_disengage_stmt(nd: DisengageStmt) -> None;
    def exit_edge_op_ref(nd: EdgeOpRef) -> None;
    def exit_edge_ref_trailer(nd: EdgeRefTrailer) -> None;
    def exit_ellipsis(nd: Ellipsis) -> None;
    def exit_else_if(nd: ElseIf) -> None;
    def exit_else_stmt(nd: ElseStmt) -> None;
    def exit_enum(nd: Enum) -> None;
    def exit_event_signature(nd: EventSignature) -> None;
    def exit_except(nd: Except) -> None;
    def exit_expr_as_item(nd: ExprAsItem) -> None;
    def exit_expr_stmt(nd: ExprStmt) -> None;
    def exit_f_string(nd: FString) -> None;
    def exit_filter_compr(nd: FilterCompr) -> None;
    def exit_finally_stmt(nd: FinallyStmt) -> None;
    def exit_float(nd: Float) -> None;
    def exit_forever_stmt(nd: ForeverStmt) -> None;
    def exit_formatted_value(nd: FormattedValue) -> None;
    def exit_func_call(nd: FuncCall) -> None;
    def exit_func_signature(nd: FuncSignature) -> None;
    def exit_gen_compr(nd: GenCompr) -> None;
    def exit_global_vars(nd: GlobalVars) -> None;
    def exit_has_var(nd: HasVar) -> None;
    def exit_if_else_expr(nd: IfElseExpr) -> None;
    def exit_if_stmt(nd: IfStmt) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def exit_import(nd: Import) -> None;
    def exit_in_for_stmt(nd: InForStmt) -> None;
    def exit_index_slice(nd: IndexSlice) -> None;
    def exit_inner_compr(nd: InnerCompr) -> None;
    def exit_int(nd: Int) -> None;
    def exit_iter_for_stmt(nd: IterForStmt) -> None;
    def exit_jsx_attribute(nd: JsxAttribute) -> None;
    def exit_jsx_child(nd: JsxChild) -> None;
    def exit_jsx_comment(nd: JsxComment) -> None;
    def exit_jsx_element(nd: JsxElement) -> None;
    def exit_jsx_element_name(nd: JsxElementName) -> None;
    def exit_jsx_expression(nd: JsxExpression) -> None;
    def exit_jsx_normal_attribute(nd: JsxNormalAttribute) -> None;
    def exit_jsx_slot(nd: JsxSlot) -> None;
    def exit_jsx_spread_attribute(nd: JsxSpreadAttribute) -> None;
    def exit_jsx_text(nd: JsxText) -> None;
    def exit_k_v_pair(nd: KVPair) -> None;
    def exit_k_w_pair(nd: KWPair) -> None;
    def exit_lambda_expr(nd: LambdaExpr) -> None;
    def exit_list_compr(nd: ListCompr) -> None;
    def exit_list_val(nd: ListVal) -> None;
    def exit_match_arch(nd: MatchArch) -> None;
    def exit_match_as(nd: MatchAs) -> None;
    def exit_match_case(nd: MatchCase) -> None;
    def exit_match_k_v_pair(nd: MatchKVPair) -> None;
    def exit_match_mapping(nd: MatchMapping) -> None;
    def exit_match_or(nd: MatchOr) -> None;
    def exit_match_sequence(nd: MatchSequence) -> None;
    def exit_match_singleton(nd: MatchSingleton) -> None;
    def exit_match_star(nd: MatchStar) -> None;
    def exit_match_stmt(nd: MatchStmt) -> None;
    def exit_match_value(nd: MatchValue) -> None;
    def exit_match_wild(nd: MatchWild) -> None;
    def exit_module(nd: Module) -> None;
    def exit_module_code(nd: ModuleCode) -> None;
    def exit_module_item(nd: ModuleItem) -> None;
    def exit_module_path(nd: ModulePath) -> None;
    def exit_multi_string(nd: MultiString) -> None;
    def exit_name(nd: Name) -> None;
    def exit_null(nd: Null) -> None;
    def exit_open_stmt(nd: OpenStmt) -> None;
    def exit_param_var(nd: ParamVar) -> None;
    def exit_py_inline_code(nd: PyInlineCode) -> None;
    def exit_raise_stmt(nd: RaiseStmt) -> None;
    def exit_report_stmt(nd: ReportStmt) -> None;
    def exit_return_stmt(nd: ReturnStmt) -> None;
    def exit_sem_def(nd: SemDef) -> None;
    def exit_semi(nd: Semi) -> None;
    def exit_set_compr(nd: SetCompr) -> None;
    def exit_set_val(nd: SetVal) -> None;
    def exit_slice(nd: Slice) -> None;
    def exit_special_var_ref(nd: SpecialVarRef) -> None;
    def exit_string(nd: String) -> None;
    def exit_sub_tag(nd: SubTag) -> None;
    def exit_switch_case(nd: SwitchCase) -> None;
    def exit_switch_stmt(nd: SwitchStmt) -> None;
    def exit_test(nd: Test) -> None;
    def exit_token(nd: Token) -> None;
    def exit_try_stmt(nd: TryStmt) -> None;
    def exit_tuple_val(nd: TupleVal) -> None;
    def exit_type_alias(nd: TypeAlias) -> None;
    def exit_type_param(nd: TypeParam) -> None;
    def exit_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def exit_unary_expr(nd: UnaryExpr) -> None;
    def exit_visit_stmt(nd: VisitStmt) -> None;
    def exit_while_stmt(nd: WhileStmt) -> None;
    def exit_with_stmt(nd: WithStmt) -> None;
    def exit_yield_expr(nd: YieldExpr) -> None;
    # <<< generated visitor surface <<<
}
