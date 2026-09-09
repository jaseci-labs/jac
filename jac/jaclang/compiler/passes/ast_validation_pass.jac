import keyword;
import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AtomTrailer,
    AtomUnit,
    BinaryExpr,
    ContextAwareNode,
    CtrlStmt,
    DeleteStmt,
    ElseStmt,
    Enum,
    ExprAsItem,
    ExprStmt,
    ForeverStmt,
    FString,
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
    Literal,
    MatchStmt,
    Module,
    ModuleCode,
    MultiString,
    Name,
    ParamVar,
    ReturnStmt,
    SpecialVarRef,
    SwitchStmt,
    Token,
    TryStmt,
    TupleVal,
    UnaryExpr,
    UniNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics {
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
    E0083,
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

walker ASTValidationPass(UniPass) {
    can enter_try_stmt with TryStmt entry;
    can enter_match_stmt with MatchStmt entry;
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
