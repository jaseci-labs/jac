import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

obj OwnershipCheckPass(UniPass) {
    has owned_syms: set[int] = set(),
        owned_names: dict[int, str] = {},
        owned_decl: dict[int, uni.Name] = {},
        consumed_syms: set[int] = set(),
        proven_unique_syms: set[int] = set(),
        borrow_syms: set[int] = set(),
        param_borrow_syms: set[int] = set(),
        borrow_names: dict[int, str] = {},
        borrow_owner: dict[int, int] = {},
        borrow_owner_node: dict[int, uni.Name] = {},
        borrow_is_mut: dict[int, bool] = {},
        e1304_borrow_ids: set[int] = set(),
        in_consumed: dict[int, set[int]] = {},
        in_live_borrows: dict[int, set[int]] = {},
        out_live_borrows: dict[int, set[int]] = {},
        in_reaching_borrows: dict[int, set[int]] = {};

    def before_pass -> None;
    def _collect_owned(tree: uni.UniNode) -> None;
    def _collect_borrows(tree: uni.UniNode) -> None;
    def _collect_params(tree: uni.UniNode) -> None;
    def _return_roots_at_param_borrow(nd: uni.Expr | None) -> bool;
    def _borrow_region(sym_id: int) -> (uni.UniScopeNode | None);
    def _region_strictly_outlives(
        dest: uni.UniScopeNode | None, region: uni.UniScopeNode | None
    ) -> bool;

    def _compute_proven_unique -> None;
    def _is_own_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _is_borrow_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_target(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_source_owner(nd: uni.Assignment) -> (uni.Name | None);
    def _assign_kill_gen(nd: uni.Assignment) -> tuple[set[int], set[int]];
    def _call_move_gen(nd: uni.UniCFGNode) -> set[int];
    def _return_move_gen(nd: uni.UniCFGNode) -> set[int];
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
    def _emit_escape_diagnostics(tree: uni.UniNode) -> None;
    def _escaping_borrow_owner(nd: uni.Expr | None) -> (str | None);
    def _is_write_target(nd: uni.Name) -> bool;
    def _is_read_name(nd: uni.Name) -> bool;
    def _target_owner_sym(nd: uni.Expr) -> (int | None);
    def _call_params(call: uni.FuncCall) -> Sequence[uni.Expr | uni.KWPair];
}
