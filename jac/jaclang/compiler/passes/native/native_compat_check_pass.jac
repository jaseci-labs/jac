"""Static analysis pass to detect native-compatible .jac modules.

Walks the module AST and checks for constructs unsupported by the native
(LLVM) backend. If the entire module is compatible, it is automatically
promoted to native context — no .na.jac extension required.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }

"""Check if a .jac module is fully compatible with native compilation.

    Runs as a UniPass visitor. Each enter_* method checks for a disqualifying
    AST node type. If none are found and the module has an entry block,
    the module is promoted to native context via _coerce_native_module().
    """
class NativeCompatCheckPass(UniPass) {
    def before_pass(self: NativeCompatCheckPass) -> None;
    def after_pass(self: NativeCompatCheckPass) -> None;
    # Disqualifying visitors
    def enter_archetype(self: NativeCompatCheckPass, nd: uni.Archetype) -> None;
    def enter_ability(self: NativeCompatCheckPass, nd: uni.Ability) -> None;
    def enter_visit_stmt(self: NativeCompatCheckPass, nd: uni.VisitStmt) -> None;
    def enter_disengage_stmt(
        self: NativeCompatCheckPass, nd: uni.DisengageStmt
    ) -> None;

    def enter_report_stmt(self: NativeCompatCheckPass, nd: uni.ReportStmt) -> None;
    def enter_yield_expr(self: NativeCompatCheckPass, nd: uni.YieldExpr) -> None;
    def enter_edge_op_ref(self: NativeCompatCheckPass, nd: uni.EdgeOpRef) -> None;
    def enter_disconnect_op(self: NativeCompatCheckPass, nd: uni.DisconnectOp) -> None;
    def enter_typed_ctx_block(
        self: NativeCompatCheckPass, nd: uni.TypedCtxBlock
    ) -> None;

    def enter_lambda_expr(self: NativeCompatCheckPass, nd: uni.LambdaExpr) -> None;
    def enter_py_inline_code(self: NativeCompatCheckPass, nd: uni.PyInlineCode) -> None;
    def enter_client_block(self: NativeCompatCheckPass, nd: uni.ClientBlock) -> None;
    def enter_server_block(self: NativeCompatCheckPass, nd: uni.ServerBlock) -> None;
    def enter_module_code(self: NativeCompatCheckPass, nd: uni.ModuleCode) -> None;
}
