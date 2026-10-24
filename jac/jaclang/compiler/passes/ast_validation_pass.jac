import keyword;


walker ASTValidationPass(TreePass) {
    static has contract: PassContract = PassContract(kernel_safe=True);

    can enter_try_stmt with TryStmt entry;
    can enter_match_stmt with MatchStmt entry;
    can enter_module with Module entry;
    can enter_module_code with ModuleCode entry;
    can enter_binary_expr with BinaryExpr entry;
    can enter_name with Name entry;
    can enter_func_signature with FuncSignature entry;
    can enter_iter_for_stmt with IterForStmt entry;
    can enter_import with Import entry;
    can enter_enum with Enum entry;
    can enter_switch_stmt with SwitchStmt entry;
    can enter_assignment with Assignment entry;
    def _check_render_phase_state_write(nd: Assignment) -> None;
    def _scope_declares_state(scope: (Ability | ImplDef), name: str) -> bool;
    def _returns_jsx(scope: (Ability | ImplDef)) -> bool;
    can enter_in_for_stmt with InForStmt entry;
    can enter_inner_compr with InnerCompr entry;
    can enter_has_var with HasVar entry;
    can enter_expr_as_item with ExprAsItem entry;
    can enter_delete_stmt with DeleteStmt entry;
    def _reject_non_bindable(target: UniNode) -> None;
    def _reject_undeletable(target: UniNode) -> None;
    can enter_param_var with ParamVar entry;
    can enter_yield_expr with YieldExpr entry;
    can enter_ctrl_stmt with CtrlStmt entry;
    can enter_global_vars with GlobalVars entry;
    can enter_func_call with FuncCall entry;
    can enter_archetype with Archetype entry;
    can enter_jsx_slot with JsxSlot entry;
    can enter_expr_stmt with ExprStmt entry;
    def _check_slot_body(stmts: list[UniNode], in_loop: bool, loop_kw: str) -> None;
    def _check_slot_else(else_body: object, in_loop: bool, loop_kw: str) -> None;
    def _slot_emits_keyless_jsx(stmts: list[UniNode]) -> bool;
    def _slot_has_key_attr(el: JsxElement) -> bool;
}
