import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
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
    E0062,
    E0063,
    E0065,
    E0066,
    E0071,
    E0075,
    E0076,
    E2019,
    E2020,
    E2021,
    E2022,
    E2024,
    W2019,
    W2020,
    W2021
}

class ASTValidationPass(UniPass) {
    def enter_try_stmt(self: ASTValidationPass, nd: uni.TryStmt) -> None;
    def enter_match_stmt(self: ASTValidationPass, nd: uni.MatchStmt) -> None;
    def enter_module_code(self: ASTValidationPass, nd: uni.ModuleCode) -> None;
    def enter_binary_expr(self: ASTValidationPass, nd: uni.BinaryExpr) -> None;
    def enter_name(self: ASTValidationPass, nd: uni.Name) -> None;
    def enter_func_signature(self: ASTValidationPass, nd: uni.FuncSignature) -> None;
    def enter_iter_for_stmt(self: ASTValidationPass, nd: uni.IterForStmt) -> None;
    def enter_import(self: ASTValidationPass, nd: uni.Import) -> None;
    def enter_enum(self: ASTValidationPass, nd: uni.Enum) -> None;
    def enter_switch_stmt(self: ASTValidationPass, nd: uni.SwitchStmt) -> None;
    def enter_assignment(self: ASTValidationPass, nd: uni.Assignment) -> None;
    def enter_in_for_stmt(self: ASTValidationPass, nd: uni.InForStmt) -> None;
    def enter_inner_compr(self: ASTValidationPass, nd: uni.InnerCompr) -> None;
    def enter_has_var(self: ASTValidationPass, nd: uni.HasVar) -> None;
    def enter_expr_as_item(self: ASTValidationPass, nd: uni.ExprAsItem) -> None;
    def enter_delete_stmt(self: ASTValidationPass, nd: uni.DeleteStmt) -> None;
    def _reject_non_bindable(self: ASTValidationPass, target: object) -> None;
    def enter_param_var(self: ASTValidationPass, nd: uni.ParamVar) -> None;
    def enter_yield_expr(self: ASTValidationPass, nd: uni.YieldExpr) -> None;
    def enter_ctrl_stmt(self: ASTValidationPass, nd: uni.CtrlStmt) -> None;
    def enter_non_local_stmt(self: ASTValidationPass, nd: uni.NonLocalStmt) -> None;
    def enter_global_vars(self: ASTValidationPass, nd: uni.GlobalVars) -> None;
    def enter_func_call(self: ASTValidationPass, nd: uni.FuncCall) -> None;
    def enter_archetype(self: ASTValidationPass, nd: uni.Archetype) -> None;
    def enter_jsx_slot(self: ASTValidationPass, nd: uni.JsxSlot) -> None;
    def _check_slot_body(
        self: ASTValidationPass, stmts: list, in_loop: bool, loop_kw: str
    ) -> None;

    def _check_slot_else(
        self: ASTValidationPass, else_body: object, in_loop: bool, loop_kw: str
    ) -> None;

    def _slot_emits_keyless_jsx(self: ASTValidationPass, stmts: list) -> bool;
    def _slot_has_key_attr(self: ASTValidationPass, el: uni.JsxElement) -> bool;
}
