import keyword;
import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AtomTrailer,
    BinaryExpr,
    ContextAwareNode,
    CtrlStmt,
    DeleteStmt,
    ElseStmt,
    Enum,
    ExprAsItem,
    ExprStmt,
    ForeverStmt,
    FuncCall,
    FuncSignature,
    GlobalVars,
    HasVar,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    InnerCompr,
    IterForStmt,
    JsxElement,
    JsxNormalAttribute,
    JsxSlot,
    KWPair,
    LambdaExpr,
    ListVal,
    MatchStmt,
    Module,
    ModuleCode,
    Name,
    ParamVar,
    ReturnStmt,
    SpecialVarRef,
    SwitchStmt,
    Token,
    TryStmt,
    TupleVal,
    UniNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.diagnostics {
    E0010,
    E0020,
    E0023,
    E0024,
    E0031,
    E0040,
    E0041,
    E0042,
    E0043,
    E0044,
    E0050,
    E0051,
    E0052,
    E0055,
    E0058,
    E0063,
    E0065,
    E0066,
    E0067,
    E0071,
    E0075,
    E0076,
    E0082,
    E2019,
    E2020,
    E2021,
    E2022,
    E2024,
    E2084,
    W2019,
    W2020,
    W2021
}

class ASTValidationPass(UniPass) {
    def enter_try_stmt(self: ASTValidationPass, nd: TryStmt) -> None;
    def enter_match_stmt(self: ASTValidationPass, nd: MatchStmt) -> None;
    def enter_module_code(self: ASTValidationPass, nd: ModuleCode) -> None;
    def enter_binary_expr(self: ASTValidationPass, nd: BinaryExpr) -> None;
    def enter_name(self: ASTValidationPass, nd: Name) -> None;
    def enter_func_signature(self: ASTValidationPass, nd: FuncSignature) -> None;
    def enter_iter_for_stmt(self: ASTValidationPass, nd: IterForStmt) -> None;
    def enter_import(self: ASTValidationPass, nd: Import) -> None;
    def enter_enum(self: ASTValidationPass, nd: Enum) -> None;
    def enter_switch_stmt(self: ASTValidationPass, nd: SwitchStmt) -> None;
    def enter_assignment(self: ASTValidationPass, nd: Assignment) -> None;
    def _check_render_phase_state_write(
        self: ASTValidationPass, nd: Assignment
    ) -> None;

    def _scope_declares_state(
        self: ASTValidationPass, scope: (Ability | ImplDef), name: str
    ) -> bool;

    def _returns_jsx(self: ASTValidationPass, scope: (Ability | ImplDef)) -> bool;
    def enter_in_for_stmt(self: ASTValidationPass, nd: InForStmt) -> None;
    def enter_inner_compr(self: ASTValidationPass, nd: InnerCompr) -> None;
    def enter_has_var(self: ASTValidationPass, nd: HasVar) -> None;
    def enter_expr_as_item(self: ASTValidationPass, nd: ExprAsItem) -> None;
    def enter_delete_stmt(self: ASTValidationPass, nd: DeleteStmt) -> None;
    def _reject_non_bindable(self: ASTValidationPass, target: object) -> None;
    def enter_param_var(self: ASTValidationPass, nd: ParamVar) -> None;
    def enter_yield_expr(self: ASTValidationPass, nd: YieldExpr) -> None;
    def enter_ctrl_stmt(self: ASTValidationPass, nd: CtrlStmt) -> None;
    def enter_global_vars(self: ASTValidationPass, nd: GlobalVars) -> None;
    def enter_func_call(self: ASTValidationPass, nd: FuncCall) -> None;
    def enter_archetype(self: ASTValidationPass, nd: Archetype) -> None;
    def enter_jsx_slot(self: ASTValidationPass, nd: JsxSlot) -> None;
    def enter_expr_stmt(self: ASTValidationPass, nd: ExprStmt) -> None;
    def _check_slot_body(
        self: ASTValidationPass, stmts: list[UniNode], in_loop: bool, loop_kw: str
    ) -> None;

    def _check_slot_else(
        self: ASTValidationPass, else_body: object, in_loop: bool, loop_kw: str
    ) -> None;

    def _slot_emits_keyless_jsx(self: ASTValidationPass, stmts: list[UniNode]) -> bool;
    def _slot_has_key_attr(self: ASTValidationPass, el: JsxElement) -> bool;
}
