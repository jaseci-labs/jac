"""GraphMend: detect PyTorch 2 graph-break locations and tag them.

Walks torch.compile entry points and tags AST nodes with a `_gm_break_kind`
marker (a `BreakKind`, see break_kind.jac) consumed by the transformation passes:

  - BreakKind.DYN_CTRL_FL : data-dependent if/else       -> PredicateCtrlFlowPass
  - BreakKind.VAL_GUARD   : data-dependent guard `raise`  -> TrapLoweringPass
  - BreakKind.SIDE_EFFECT : print / logger call           -> DeferSideEffectPass

A condition is data-dependent if it uses a dynamic torch attribute (see
torch_attr_table) directly, or a use-def trace over the symbol table shows it
derives from one. Gated by --graphmend: prunes when off or no entry point.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    is_dynamic_torch_attr,
    is_side_effect_name
}
import from jaclang.compiler.passes.main.graphmend.break_kind { BreakKind }

"""Tag graph-break locations under torch.compile entry points."""
obj GraphBreakDetectPass(UniPass) {
    has _enabled: bool = False,
        _whole_module: bool = False,
        _entry_ids: set[int] = set();

    def before_pass -> None;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_func_call(nd: uni.FuncCall) -> None;
    # -- entry-point analysis --
    def _collect_entry_points -> set[int];
    def _call_is_torch_compile(call: uni.FuncCall) -> bool;
    def _resolve_wrapped_entry(call: uni.FuncCall) -> (uni.UniNode | None);
    def _def_node(name: str, ctx: uni.UniNode) -> (uni.UniNode | None);
    def _var_assignment(name: str, ctx: uni.UniNode) -> (uni.Assignment | None);
    def _has_torch_compile_decorator(nd: uni.UniNode) -> bool;
    def _in_torch_compiled_scope(nd: uni.UniNode) -> bool;
    # -- break classification --
    def _call_name(nd: uni.FuncCall) -> (str | None);
    def _is_user_defined(nd: uni.FuncCall, name: str) -> bool;
    def _is_validation_guard(nd: uni.IfStmt) -> bool;
    def _body_ends_in_raise(nd: uni.IfStmt) -> bool;
    def _condition_is_data_dependent(cond: uni.Expr) -> bool;
    def _expr_uses_dynamic_attr(expr: uni.Expr) -> bool;
    def _trace_symbol(sym: uni.Symbol, visited: set[int], depth: int) -> bool;
    def _defining_assignments(sym: uni.Symbol) -> list[uni.Assignment];
    def _defining_assignment(sym: uni.Symbol) -> (uni.Assignment | None);
}
