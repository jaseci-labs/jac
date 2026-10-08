import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.context { TreePass }

walker GraphBreakDetectPass(TreePass) {
    has _enabled: bool = False,
        _saw_compile_call: bool = False,
        _entry_ids: set[int] = set(),
        _spine_ids: set[int] = set(),
        _mat_seen: set[str] = set();

    can prepare with entry;
    def _record_noop(local: bool) -> None;
    def _in_torch_compiled_scope(nd: uni.UniNode) -> bool;
    can enter_ability with uni.Ability entry;
    can enter_if_stmt with uni.IfStmt entry;
    can enter_func_call with uni.FuncCall entry;
    def _call_name(nd: uni.FuncCall) -> (str | None);
    def _base_binds_logger(t: uni.AtomTrailer) -> bool;
    def _is_user_defined(nd: uni.FuncCall, name: str) -> bool;
}
