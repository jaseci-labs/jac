import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphMendHelper }
import from jaclang.jac0core.passes { UniPass }

obj DeferSideEffectPass(UniPass) {
    has _enabled: bool = False,
        _counter: int = 0,
        _se_arg_counter: int = 0,
        _needs_se: set[int] = set(),
        _guarded: set[int] = set(),
        _defer_mods: set[int] = set(),
        _pending_regs: list[tuple[(uni.Archetype | None), uni.Assignment]] = [];

    static has _LOG_METHODS: set[str] = {
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
    def _logger_emit(nd: uni.FuncCall) -> (uni.FuncCall | None);
    def _register_assignment(
        at: uni.UniNode, slot_name: str, callee: uni.Expr
    ) -> uni.Assignment;

    def _toplevel_archetype(nd: uni.UniNode) -> (uni.Archetype | None);
    def _pre_hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt;
    def _hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt;
    def _attach_se_guard(nd: uni.Ability) -> None;
    def _is_compiled_entry(nd: uni.Ability) -> bool;
    def _need_helper(at: uni.UniNode, helper: GraphMendHelper) -> None;
    def _gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name;
    def _str(at: uni.UniNode, text: str) -> uni.String;
    def _split_params(params: any) -> tuple[list[uni.Expr], list[uni.KWPair]];

    def _tuple(at: uni.UniNode, values: list[uni.Expr]) -> uni.TupleVal;
    def _dict_from_kws(at: uni.UniNode, kws: list[uni.KWPair]) -> uni.DictVal;
    def _buffer_entry(call: uni.FuncCall) -> tuple[uni.TupleVal, list[uni.UniNode]];

    def _clone_guard(at: uni.UniNode, tmp: str) -> uni.IfElseExpr;
    def _buffer_append(at: uni.UniNode, ent: uni.TupleVal) -> uni.FuncCall;
    def _flush_stmt(at: uni.UniNode) -> uni.ExprStmt;
    def _append_stmt(ability: uni.Ability, new_stmt: uni.UniNode) -> None;
    def _append_module_stmt(mod: uni.Module, new_stmt: uni.UniNode) -> None;
    def _insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None;
    def _insert_before(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None;
}
