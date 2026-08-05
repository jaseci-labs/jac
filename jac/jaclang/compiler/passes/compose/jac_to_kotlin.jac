import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }

obj JacToKotlin {
    has reactive_vars: set[str] = set(),
        diagnostics: list[str] = [],
        declared_locals: set[str] = set(),
        _mutable_locals: set[str] = set();

    def convert_expr(nd: (uni.UniNode | None)) -> (kt.KtNode | None);
    def convert_stmts(body: (list[uni.UniNode] | None)) -> list[kt.KtNode];
    def convert_stmt(nd: (uni.UniNode | None)) -> (kt.KtNode | None);
    def _compute_mutable_locals(body: (list[uni.UniNode] | None)) -> set[str];
    def _count_assign_targets(
        nd: (uni.UniNode | None), counts: dict[str, int]
    ) -> None;

    def lower_state_read(name: str) -> kt.KtNode;
    def _lambda_body(nd: uni.LambdaExpr) -> list[kt.KtNode];
    def _convert_spawn(nd: uni.BinaryExpr) -> (kt.KtNode | None);
    def _resolve_spawn_walker(expr: uni.Expr) -> (tuple[str, uni.FuncCall] | None);
    def _resolve_spawn_target(expr: uni.Expr) -> (kt.KtNode | None);
    def _is_root_reference(expr: uni.Expr) -> bool;
    def _spawn_request_named_args(call: uni.FuncCall) -> list[kt.KtNamedArg];
}

def jac_expr_to_kt(
    nd: (uni.UniNode | None), reactive_vars: set[str] = {}
) -> (kt.KtNode | None);

def jac_stmts_to_kt(
    body: (list[uni.UniNode] | None), reactive_vars: set[str] = {}
) -> list[kt.KtNode];
