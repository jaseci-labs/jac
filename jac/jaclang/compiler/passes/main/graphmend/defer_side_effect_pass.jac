import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

obj DeferSideEffectPass(UniPass) {
    has _enabled: bool = False,
        _counter: int = 0,
        _se_arg_counter: int = 0,
        _needs_se: set[int] = set(),
        _guarded: set[int] = set(),
        _defer_mods: set[int] = set(),
        _pending_regs: list[tuple[(uni.Archetype | None), uni.Assignment]] = [];

    static has REQUIRES: tuple = ('graph-breaks', 'predicated-branches'),
        _LOG_METHODS: set[str] = {
            'debug',
            'info',
            'warning',
            'warning_once',
            'error',
            'exception',
            'critical',
            'fatal',
            'log',
            'warn'
        };

    def before_pass -> None;
    def exit_func_call(nd: uni.FuncCall) -> None;
    def exit_assignment(nd: uni.Assignment) -> None;
    def exit_return_stmt(nd: uni.ReturnStmt) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_module(nd: uni.Module) -> None;
    def _is_logger_call(nd: uni.FuncCall) -> bool;
    def _base_binds_at_module(base: uni.Name) -> bool;
    def _logger_emit(nd: uni.FuncCall) -> (uni.FuncCall | None);
    def _register_assignment(
        at: uni.UniNode, slot_name: str, callee: uni.Expr
    ) -> uni.Assignment;

    def _toplevel_archetype(nd: uni.UniNode) -> (uni.Archetype | None);
    def _pre_hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt;
    def _hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt;
    def _hook_guard_stmt(at: uni.UniNode, name: str, body: list) -> uni.IfStmt;
    def _attach_se_guard(nd: uni.Ability) -> None;
    def _is_compiled_entry(nd: uni.Ability) -> bool;
    def _str(at: uni.UniNode, text: str) -> uni.String;
    def _has_unpack(call: uni.FuncCall) -> bool;
    def _tuple(at: uni.UniNode, values: list[uni.Expr]) -> uni.TupleVal;
    def _dict_from_kws(at: uni.UniNode, kws: list[uni.KWPair]) -> uni.DictVal;
    def _buffer_entry(call: uni.FuncCall) -> tuple[uni.TupleVal, list[uni.UniNode]];
    def _snapshot(
        call: uni.FuncCall, v: uni.Expr, hoists: list[uni.UniNode]
    ) -> uni.Expr;

    def _clone_guard(at: uni.UniNode, tmp: str) -> uni.IfElseExpr;
    def _buffer_append(at: uni.UniNode, ent: uni.TupleVal) -> uni.FuncCall;
    def _flush_stmt(at: uni.UniNode) -> uni.ExprStmt;
}
