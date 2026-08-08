import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphMendHelper }
import from jaclang.jac0core.passes { UniPass }

glob _TENSOR_BOOL_OPS: set[str] = {'all', 'any', 'allclose'};

obj TrapLoweringPass(UniPass) {
    has _enabled: bool = False,
        _guarded_fns: set[int] = set();

    def before_pass -> None;
    def _need_helper(at: uni.UniNode, helper: GraphMendHelper) -> None;
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def _enclosing_compiled_fn(nd: uni.UniNode) -> (uni.Ability | None);
    def _exception_type_name(rs: uni.RaiseStmt) -> (str | None);
    def _marked_message(
        at: uni.UniNode, msg: uni.Expr, type_name: str
    ) -> (uni.String | None);

    def _mark_guard(ability: (uni.Ability | None)) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def _torch_equal_args(x: uni.Expr) -> (tuple | None);
    def _returns_tensor_bool(x: uni.Expr) -> bool;
    def _raise_message(rs: uni.RaiseStmt, at: uni.UniNode) -> uni.Expr;
    def _gen_name(at: uni.UniNode, value: str) -> uni.Name;
    def _str(at: uni.UniNode, text: str) -> uni.String;
    def _call_stmt(call: uni.FuncCall) -> uni.ExprStmt;
    def _eq_assert_stmt(
        at: uni.UniNode, a: uni.Expr, b: uni.Expr, msg: uni.Expr
    ) -> uni.ExprStmt;

    def _assert_async_stmt(
        at: uni.UniNode, x: uni.Expr, msg: uni.Expr
    ) -> uni.ExprStmt;

    def _replace(old: uni.UniNode, new_nodes: list) -> None;
}
