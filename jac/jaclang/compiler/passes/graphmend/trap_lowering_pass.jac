import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.context { TreePass }

glob _TENSOR_BOOL_OPS: set[str] = {'all', 'any', 'allclose'};

walker TrapLoweringPass(TreePass) {
    has _enabled: bool = False,
        _guarded_fns: list[uni.Ability] = [],
        _tensor_trace: set[str] = set();

    can prepare with entry;
    can exit_if_stmt with uni.IfStmt exit;
    can exit_assignment with uni.Assignment exit;
    def _boundary_attach_stmt(at: uni.UniNode, name: str) -> uni.Assignment;
    def _inside_try(nd: uni.UniNode) -> bool;
    def _boundary_ability(nd: uni.UniNode) -> (uni.Ability | None);
    def _call_site_covered(nd: uni.UniNode) -> bool;
    def _covering_entry(nd: uni.UniNode) -> (str | None);
    def _exception_type_name(rs: uni.RaiseStmt) -> (str | None);
    def _marked_message(
        at: uni.UniNode, msg: uni.Expr, type_name: str
    ) -> (uni.String | None);

    def _mark_guard(ability: (uni.Ability | None)) -> None;
    can finish with exit;
    def _torch_equal_args(x: uni.Expr) -> (tuple[uni.Expr, uni.Expr] | None);
    def _returns_tensor_bool(x: uni.Expr) -> bool;
    def _condition_is_tensor(cond: uni.Expr, site: uni.UniNode) -> bool;
    def _operand_is_tensor(e: uni.Expr, site: uni.UniNode) -> bool;
    def _tensor_receiver_provable(x: uni.Expr, site: uni.UniNode) -> bool;
    def _tensor_expr_provable(e: uni.Expr, site: uni.UniNode) -> bool;
    def _assigned_tensor_provable(nm: uni.Name, site: uni.UniNode) -> bool;
    def _param_is_tensor(name: str, site: uni.UniNode) -> bool;
    def _binds_torch_tensor(ann: uni.Name) -> bool;
    def _torch_binds_module(site: uni.UniNode) -> bool;
    def _raise_message(rs: uni.RaiseStmt) -> (uni.Expr | None);
    def _gen_name(at: uni.UniNode, value: str) -> uni.Name;
    def _str(at: uni.UniNode, text: str) -> uni.String;
    def _call_stmt(call: uni.FuncCall) -> uni.ExprStmt;
    def _eq_assert_stmt(
        at: uni.UniNode, a: uni.Expr, b: uni.Expr, msg: uni.Expr
    ) -> uni.ExprStmt;

    def _assert_async_stmt(
        at: uni.UniNode, x: uni.Expr, msg: uni.Expr
    ) -> uni.ExprStmt;
}
