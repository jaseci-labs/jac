import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

obj GraphBreakDetectPass(UniPass) {
    has _enabled: bool = False,
        _entry_ids: set[int] = set();

    def before_pass -> None;
    def _collect_entry_points -> set[int];
    def _in_torch_compiled_scope(nd: uni.UniNode) -> bool;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def _body_is_only_raise(body: Sequence[uni.CodeBlockStmt]) -> bool;
    def _expr_uses_dynamic_attr(expr: uni.Expr) -> bool;
}
