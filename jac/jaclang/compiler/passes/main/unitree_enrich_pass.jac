"""Pre-computes backend-neutral analysis on AST nodes so codegen passes
are pure code generation. Populates Expr.backend_type_tag, Name.js_decl_kind,
and Module.gen.native_compat."""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

"""Convert a TypeBase to a backend-neutral type tag string, or None."""
def _typebase_to_tag(t: Any) -> (str | None);

"""Pre-compute backend hints on every Expr and Name node."""
obj UniTreeEnrichPass(UniPass) {
    def before_pass -> None;
    def enter_expr(nd: uni.Expr) -> None;
    def enter_name(nd: uni.Name) -> None;
    def enter_archetype(nd: uni.Archetype) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def enter_visit_stmt(nd: uni.VisitStmt) -> None;
    def enter_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def enter_report_stmt(nd: uni.ReportStmt) -> None;
    def enter_yield_expr(nd: uni.YieldExpr) -> None;
    def enter_edge_op_ref(nd: uni.EdgeOpRef) -> None;
    def enter_disconnect_op(nd: uni.DisconnectOp) -> None;
    def enter_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    def enter_lambda_expr(nd: uni.LambdaExpr) -> None;
    def enter_py_inline_code(nd: uni.PyInlineCode) -> None;
    def enter_client_block(nd: uni.ClientBlock) -> None;
    def enter_server_block(nd: uni.ServerBlock) -> None;
    def enter_module_code(nd: uni.ModuleCode) -> None;
    def exit_module(nd: uni.Module) -> None;
}
