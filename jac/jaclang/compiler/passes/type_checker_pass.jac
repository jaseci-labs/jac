glob FW_INTERVAL_OPS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*"
     };

walker TypeCheckPass(TreeWalker) {
    can enter_walk with UniNode entry {
        self.ctx.enter_node(here);
    }

    can exit_walk with UniNode exit {
        self.ctx.exit_node(here);
    }

    has ctx: CompileContext,
        module: Module,
        prog: JacProgram,
        evaluator: TypeEvaluator postinit,
        _deferred_writes: list[tuple[Expr, (UniNode | None)]] postinit,
        _lambda_depth: int = 0;

    def postinit -> None;
    can initialize with entry;

    static has HOST_PASS: bool = True;

    can prepare with entry;
    can finish with exit;
    def _stamp_fixed_width -> None;
    def _provably_in_range(nd: Expr, name: str) -> bool;
    def _insert_builtin_symbols -> None;
    def _install_client_state_setters -> None;
    def _client_state_field_owner(nd: HasVar) -> (Ability | None);
    can enter_ability with Ability entry;
    can exit_ability with Ability exit;
    can enter_lambda_expr with LambdaExpr entry;
    can exit_lambda_expr with LambdaExpr exit;
    can exit_type_alias with TypeAlias exit;
    can exit_archetype with Archetype exit;
    can exit_enum with Enum exit;
    can exit_import with Import exit;
    can exit_assignment with Assignment exit;
    can exit_atom_trailer with AtomTrailer exit;
    can exit_binary_expr with BinaryExpr exit;
    can exit_compare_expr with CompareExpr exit;
    def _diag_erased_membership(nd: CompareExpr, hay: Expr, op_text: str) -> None;
    can exit_func_call with FuncCall exit;
    def _c_instance_of(ann_node: (UniNode | None)) -> (TypeBase | None);
    def _c_plain_data(t: (TypeBase | None), allow_callable: bool = False) -> bool;
    def _opaque_member(t: (TypeBase | None)) -> (Archetype | None);
    def _check_c_type_use(ann_node: (UniNode | None)) -> None;
    def _check_c_interop_import(imp: Import) -> None;
    def _foreign_struct_contains(t: (TypeBase | None), target: Archetype) -> bool;
    def _check_c_interop_call(nd: FuncCall) -> None;
    def _c_arg_instance(t: (TypeBase | None)) -> (TypeBase | None);
    can exit_gen_compr with GenCompr exit;
    def _check_intrinsic_collision(nd: Ability) -> None;
    can exit_jsx_element with JsxElement exit;
    can exit_filter_compr with FilterCompr exit;
    can exit_return_stmt with ReturnStmt exit;
    can exit_formatted_value with FormattedValue exit;
    can exit_edge_ref_trailer with EdgeRefTrailer exit;
    can exit_special_var_ref with SpecialVarRef exit;
    can exit_name with Name exit;
    can exit_param_var with ParamVar exit;
    can exit_has_var with HasVar exit;
    can exit_in_for_stmt with InForStmt exit;
    can exit_raise_stmt with RaiseStmt exit;
    can exit_except with Except exit;
    can exit_match_as with MatchAs exit;
    can enter_with_stmt with WithStmt entry;
    can exit_with_stmt with WithStmt exit;
    can enter_if_stmt with IfStmt entry;
    can enter_else_if with ElseIf entry;
    def _resolve_comptime_if(nd: IfStmt) -> None;
    def _in_comptime_context(nd: UniNode) -> bool;
    def _check_comptime_only_use(nd: Name) -> None;
    def _check_type_only_value_use(nd: Name) -> None;
    can exit_if_stmt with IfStmt exit;
    can exit_else_if with ElseIf exit;
    can exit_while_stmt with WhileStmt exit;
    can exit_assert_stmt with AssertStmt exit;
    can exit_yield_expr with YieldExpr exit;
    can exit_delete_stmt with DeleteStmt exit;
    can exit_visit_stmt with VisitStmt exit;
    can exit_report_stmt with ReportStmt exit;
    can exit_impl_def with ImplDef exit;
    can exit_sub_tag with SubTag exit;
    def _eval_unpacking_names(container: Expr) -> None;
    def _write_leaves(target: (Expr | None)) -> list[Expr];
    def _check_immutable_write(
        target: (Expr | None), rebind_scope: (UniNode | None) = None
    ) -> None;

    def _flush_immutable_writes -> None;
    def _judge_immutable_write(
        target: (Expr | None), rebind_scope: (UniNode | None) = None
    ) -> None;

    def _rebound_enclosing_symbol(scope: UniNode, leaf: Name) -> (Symbol | None);
    def _is_initializer_write(target: Expr, decl_sym: Symbol) -> bool;
    def _is_self_ref(base: Name, method: Ability) -> bool;
    def _body_always_returns(body: list[CodeBlockStmt]) -> bool;
    def _check_bare_generic(
        ann_node: UniNode,
        ty: object,
        shape: (UniNode | None) = None,
        nested: bool = False
    ) -> None;

    def _written_type_args(
        shape: (UniNode | None), ty: ClassType
    ) -> (list[Expr] | None);

    def _index_args(index: IndexSlice) -> list[Expr];
    def _union_leaves(shape: (UniNode | None)) -> list[UniNode];
    def _names_union_form(target: Expr) -> bool;
    def _check_explicit_any(ann_node: UniNode) -> None;
    def _check_walker_reports_shape(nd: HasVar, declared_type: object) -> None;
    def _enclosing_walker_report_elem_type(nd: UniNode) -> (TypeBase | None);
    def _jsx_component_params(nd: Ability) -> (list[ParamVar] | None);
    def _is_ref_forward_tail_param(p: ParamVar) -> bool;
    def _check_props_bundle_is_exclusive(
        nd: Ability, comp_params: list[ParamVar]
    ) -> None;

    def _check_event_trigger_archetype(nd: Ability) -> None;
    def _check_unresolved_lambda_params -> None;
}
