import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

glob _PURE_BUILTINS: set[str] = {
         'len',
         'float',
         'int',
         'bool',
         'str',
         'max',
         'min',
         'abs',
         'sum',
         'list',
         'tuple',
         'range',
         'getattr',
         'hasattr'
     },
     _PURE_TENSOR_METHODS: set[str] = {
         'to',
         'float',
         'double',
         'clone',
         'detach',
         'get'
     };

obj PredicateCtrlFlowPass(UniPass) {
    has _enabled: bool = False,
        _counter: int = 0;

    def before_pass -> None;
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def _rewrite_assignment(
        nd: uni.IfStmt, lhs: uni.Name, true_e: uni.Expr, false_e: uni.Expr
    ) -> None;

    def _rewrite_return(nd: uni.IfStmt, true_e: uni.Expr, false_e: uni.Expr) -> None;
    def _merge_common_call(
        nd: uni.IfStmt,
        ca: uni.Expr,
        cb: uni.Expr,
        true_setups: Sequence[uni.CodeBlockStmt],
        false_setups: Sequence[uni.CodeBlockStmt]
    ) -> None;

    def _use_cond(true_e: uni.Expr, false_e: uni.Expr) -> bool;
    def _unfixable_call_literal(true_e: uni.Expr, false_e: uni.Expr) -> bool;
    def _has_call(e: uni.UniNode) -> bool;
    def _has_none(a: uni.Expr, b: uni.Expr) -> bool;
    def _same_lhs(a: uni.Assignment, b: uni.Assignment) -> (uni.Name | None);
    def _split_params(params: any) -> tuple[list[uni.Expr], dict[str, uni.KWPair]];
    def _gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name;
    def _assign(target: uni.Name, value: uni.Expr) -> uni.Assignment;
    def _make_where(
        at: uni.UniNode, cond: uni.Expr, t: uni.Expr, f: uni.Expr
    ) -> uni.FuncCall;

    def _make_cond(
        at: uni.UniNode, pred: uni.Expr, t: uni.Expr, f: uni.Expr
    ) -> uni.FuncCall;

    def _torch_call(at: uni.UniNode, fname: str, args: list) -> uni.FuncCall;
    def _hoist(
        at: uni.UniNode, cond: uni.Expr, t: uni.Expr, f: uni.Expr
    ) -> tuple[list, uni.Name, uni.Name, uni.Name];

    def _hoist_cond(at: uni.UniNode, cond: uni.Expr) -> tuple[list, uni.Name];
    def _is_assert_async(stmt: uni.UniNode) -> bool;
    def _is_eq_assert(stmt: uni.UniNode) -> bool;
    def _gate_asserts(setups: list, n: int, taken_when_true: bool) -> list;
    def _replace(old: uni.UniNode, new_nodes: list) -> None;
    def _setups_safe(setups: Sequence[uni.CodeBlockStmt], region: uni.IfStmt) -> bool;
    def _effect_neutral(s: uni.UniNode, region: uni.IfStmt) -> bool;
    def _is_existence_guard(s: uni.UniNode, region: uni.IfStmt) -> bool;
    def _init_value_safe(v: (uni.Expr | uni.YieldExpr | None)) -> bool;
    def _call_speculatable(c: uni.FuncCall) -> bool;
    def _signature_accepts(fn: uni.Ability, c: uni.FuncCall) -> bool;
    def _module_fn(mod: uni.Module, name: str) -> (uni.Ability | None);
    def _dispatch_table_fns(mod: uni.Module) -> list[uni.Ability];
    def _body_pure_nonraising(
        fn: uni.Ability, c: uni.FuncCall, seen: (set[int] | None) = None
    ) -> bool;

    def _hasattr_key(c: uni.Expr) -> (tuple[str, str] | None);
    def _writes_attr(s: uni.Assignment, recv: str, key: str) -> bool;
    def _attr_confined(region: uni.IfStmt, key: str) -> bool;
    def _within(nd: uni.UniNode, anc: uni.UniNode) -> bool;
    def _varkw_name(fn: uni.Ability) -> (str | None);
    def _passes_extra_kwargs(fn: uni.Ability, c: uni.FuncCall) -> bool;
    def _guarded_by_varkw(r: uni.RaiseStmt, varkw: str, fn: uni.Ability) -> bool;
    def _mentions_name(e: (uni.Expr | None), nm: str) -> bool;
    def _pure_callee(t: (uni.Expr | None)) -> bool;
    def _assignment_neutral(s: uni.Assignment) -> bool;
    def _is_device_move(s: uni.Assignment) -> bool;
    def _all_local_targets(targets: Sequence[uni.Expr]) -> bool;
}
