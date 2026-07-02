"""Ownership / borrow check pass (Phase 1 — diagnostics only).

Tracks opt-in `own`, `&`, and `&mut` bindings without changing codegen.
Unannotated code is untouched. See docs/borrow-checker-brief.md.

The pass uses the statement-level CFG from CFGBuildPass. Move checking is a
forward may-consume analysis: a symbol is considered consumed at a join if it
was consumed on any incoming path. Borrow checking uses the same CFG with two
additional facts: a backward liveness set for borrow variables and a forward
reaching-definition set for borrow assignments. Their intersection answers
"which initialized borrows are live at this program point" for E1302/E1303.

E1304 is the Phase-1 second-class borrow check: a borrow variable may not be
read outside the nearest UniScopeNode that owns the borrowed binding. E1305 is
a narrow "never consumed" check over the owner symbols seen by the move
transfer.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }

obj OwnershipCheckPass(UniPass) {
    # id(Symbol) of every `own`-annotated binding, and its display name.
    has owned_syms: set[int] = set(),
        owned_names: dict[int, str] = {},
        owned_decl: dict[int, uni.Name] = {},
        consumed_syms: set[int] = set(),
        # id(Symbol) of every `&`/`&mut` local, mapped to the owner it borrows.
        borrow_syms: set[int] = set(),
        borrow_names: dict[int, str] = {},
        borrow_owner: dict[int, int] = {},
        borrow_owner_node: dict[int, uni.Name] = {},
        borrow_is_mut: dict[int, bool] = {},
        # id(UniCFGNode) -> set of consumed owned-sym ids on entry to that node.
        in_consumed: dict[int, set[int]] = {},
        # id(UniCFGNode) -> live borrow variable ids before/after the node.
        in_live_borrows: dict[int, set[int]] = {},
        out_live_borrows: dict[int, set[int]] = {},
        # id(UniCFGNode) -> borrow variables initialized on paths reaching node.
        in_reaching_borrows: dict[int, set[int]] = {};

    def before_pass -> None;

    def _collect_owned(tree: uni.UniNode) -> None;
    def _collect_borrows(tree: uni.UniNode) -> None;
    def _is_own_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _is_borrow_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_target(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_source_owner(nd: uni.Assignment) -> (uni.Name | None);
    def _assign_kill_gen(nd: uni.Assignment) -> tuple[set[int], set[int]];
    def _call_move_gen(nd: uni.UniCFGNode) -> set[int];
    def _transfer(nd: uni.UniCFGNode, in_set: set[int]) -> set[int];
    def _run_dataflow(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _borrow_read_gen(nd: uni.UniCFGNode) -> set[int];
    def _borrow_assign_kill_gen(nd: uni.UniCFGNode) -> tuple[set[int], set[int]];
    def _run_borrow_liveness(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _run_reaching_borrows(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _nearest_cfg(nd: uni.UniNode) -> (uni.UniCFGNode | None);
    def _nearest_scope(nd: uni.UniNode) -> (uni.UniScopeNode | None);
    def _is_ancestor(ancestor: uni.UniNode, nd: uni.UniNode) -> bool;
    def _emit_diagnostics(tree: uni.UniNode) -> None;
    def _emit_borrow_diagnostics(tree: uni.UniNode) -> None;
    def _emit_leak_diagnostics -> None;
    def _is_write_target(nd: uni.Name) -> bool;
    def _is_read_name(nd: uni.Name) -> bool;
    def _target_owner_sym(nd: uni.Expr) -> (int | None);
    def _call_params(call: uni.FuncCall) -> Sequence[uni.Expr | uni.KWPair];
}
