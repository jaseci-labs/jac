import from collections.abc { Callable, Sequence }
import from enum { Enum }
import from typing { TypeAlias }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

glob SymId: TypeAlias = int,
     DataflowTransfer: TypeAlias = Callable[[uni.UniCFGNode, set[SymId]], set[SymId]];

enum AccessKind {
    ASSIGN_TARGET = "assign_target",
    ATTR_TARGET = "attr_target",
    SUBSCRIPT_TARGET = "subscript_target",
    DESTRUCTURE_TARGET = "destructure_target",
    DELETE_TARGET = "delete_target",
    CALL_ARG = "call_arg",
    RETURN_VALUE = "return_value",
    READ = "read"
}

obj BorrowMeta {
    has name: str,
        owner: (SymId | None) = None,
        is_mut: bool = False;
}

obj OwnershipCheckPass(UniPass) {
    has owned_syms: set[SymId] = set(),
        owned_decl: dict[SymId, uni.Name] = {},
        consumed_syms: set[SymId] = set(),
        proven_unique_syms: set[SymId] = set(),
        borrow_syms: set[SymId] = set(),
        param_borrow_syms: set[SymId] = set(),
        borrow_meta: dict[SymId, BorrowMeta] = {},
        e1304_borrow_ids: set[SymId] = set(),
        in_consumed: dict[int, set[SymId]] = {},
        in_live_borrows: dict[int, set[SymId]] = {},
        in_reaching_borrows: dict[int, set[SymId]] = {},
        consumed_at: dict[SymId, uni.UniNode] = {},
        borrow_created_at: dict[SymId, uni.UniNode] = {},
        loop_depth_flagged_names: set[int] = set(),
        idx_assignments: list[uni.Assignment] = [],
        idx_names: list[uni.Name] = [],
        idx_params: list[uni.ParamVar] = [],
        idx_returns: list[uni.ReturnStmt] = [],
        idx_concurrent: list[uni.ConcurrentExpr] = [],
        name_uses_by_sym: dict[SymId, list[uni.Name]] = {};

    def before_pass -> None;
    def _build_index(tree: uni.UniNode) -> None;
    def _collect_owned -> None;
    def _collect_borrows -> None;
    def _collect_params -> None;
    def _return_roots_at_param_borrow(nd: uni.Expr | None) -> bool;
    def _borrow_region(sym_id: SymId) -> (uni.UniScopeNode | None);
    def _region_strictly_outlives(
        dest: uni.UniScopeNode | None, region: uni.UniScopeNode | None
    ) -> bool;

    def _compute_proven_unique -> None;
    def _is_own_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _is_borrow_decl(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_target(nd: uni.Assignment) -> (uni.Name | None);
    def _borrow_source_owner(nd: uni.Assignment) -> (uni.Name | None);
    def _assign_kill_gen(nd: uni.Assignment) -> tuple[set[SymId], set[SymId]];
    def _call_move_gen(nd: uni.UniCFGNode) -> set[SymId];
    def _return_move_gen(nd: uni.UniCFGNode) -> set[SymId];
    def _solve_forward_dataflow(
        cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
    ) -> dict[int, set[SymId]];

    def _solve_backward_dataflow(
        cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
    ) -> dict[int, set[SymId]];

    def _transfer(nd: uni.UniCFGNode, in_set: set[SymId]) -> set[SymId];
    def _run_dataflow(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _borrow_read_gen(nd: uni.UniCFGNode) -> set[SymId];
    def _borrow_assign_kill_gen(nd: uni.UniCFGNode) -> tuple[set[SymId], set[SymId]];
    def _reaching_transfer(nd: uni.UniCFGNode, in_set: set[SymId]) -> set[SymId];
    def _live_transfer(nd: uni.UniCFGNode, out_set: set[SymId]) -> set[SymId];
    def _run_borrow_liveness(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _run_reaching_borrows(cfg_nodes: list[uni.UniCFGNode]) -> None;
    def _nearest_cfg(nd: uni.UniNode) -> (uni.UniCFGNode | None);
    def _nearest_scope(nd: uni.UniNode) -> (uni.UniScopeNode | None);
    def _is_ancestor(ancestor: uni.UniNode, nd: uni.UniNode) -> bool;
    def _loop_depth(nd: uni.UniNode) -> int;
    def _emit_loop_move_diagnostics -> None;
    def _emit_diagnostics -> None;
    def _emit_borrow_diagnostics -> None;
    def _emit_leak_diagnostics -> None;
    def _emit_escape_diagnostics -> None;
    def _escaping_borrow_owner(nd: uni.Expr | None) -> (str | None);
    def _owner_decl_related(
        borrow_id: (SymId | None), owner_name: str
    ) -> (list[tuple[str, uni.UniNode]] | None);

    def _sym_id(nd: uni.UniNode | None) -> (SymId | None);
    def _owned_sym_of(nd: uni.UniNode | None) -> (SymId | None);
    def _borrow_sym_of(nd: uni.UniNode | None) -> (SymId | None);
    def _owned_name(sym_id: SymId, fallback: str) -> str;
    def _borrow_owner_of(borrow_id: SymId) -> (SymId | None);
    def _borrow_is_mut_of(borrow_id: SymId) -> bool;
    def _borrow_display_name(borrow_id: SymId, fallback: str) -> str;
    def _classify_access(nd: uni.Name) -> AccessKind;
    def _is_write_target(nd: uni.Name) -> bool;
    def _is_read_name(nd: uni.Name) -> bool;
    def _target_owner_sym(nd: uni.Expr) -> (SymId | None);
    def _call_params(call: uni.FuncCall) -> Sequence[uni.Expr | uni.KWPair];
}
