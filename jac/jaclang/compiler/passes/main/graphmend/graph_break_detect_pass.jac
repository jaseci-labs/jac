import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

obj GraphBreakDetectPass(UniPass) {
    has _enabled: bool = False,
        _saw_compile_call: bool = False,
        _entry_ids: set[int] = set(),
        _spine_ids: set[int] = set(),
        _mat_seen: set[str] = set();

    static has PROVIDES: tuple = ('graph-breaks', );

    def before_pass -> None;
    def _record_noop(local: bool) -> None;
    def _in_torch_compiled_scope(nd: uni.UniNode) -> bool;
    def enter_ability(nd: uni.Ability) -> None;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_func_call(nd: uni.FuncCall) -> None;
    def _call_name(nd: uni.FuncCall) -> (str | None);
    def _base_binds_logger(t: uni.AtomTrailer) -> bool;
    def _is_user_defined(nd: uni.FuncCall, name: str) -> bool;
}
