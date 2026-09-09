import from enum { Enum }
import from typing { TypeAlias }
import from jaclang.compiler.frontend.unitree {
    Ability,
    AstElseBodyNode,
    Archetype,
    Assignment,
    AtomTrailer,
    BinaryExpr,
    CfgExpr,
    ConcurrentExpr,
    ConnectOp,
    CtrlStmt,
    DeleteStmt,
    DictVal,
    DisengageStmt,
    Enum as UniEnum,
    Expr,
    FString,
    FuncCall,
    FuncSignature,
    GlobalVars,
    HasVar,
    IfElseExpr,
    Import,
    InForStmt,
    IndexSlice,
    Int,
    IterForStmt,
    KWPair,
    LambdaExpr,
    ListVal,
    Module,
    ModuleCode,
    MultiString,
    Name,
    OpenStmt,
    ParamVar,
    RaiseStmt,
    FinallyStmt,
    Except,
    TryStmt,
    ReturnStmt,
    SetVal,
    Slice,
    String,
    SubTag,
    Token,
    TupleVal,
    UnaryExpr,
    UniCFGNode,
    UniNode,
    UniScopeNode,
    WhileStmt,
    YieldExpr
}
import from jaclang.compiler.frontend.constant {
    Tokens as Tok,
    OwnershipKind,
    SymbolStorage,
    is_borrow_kind,
    is_mut_kind
}
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.passes.dataflow {
    solve_backward,
    solve_forward,
    solve_forward_must
}
import type from jaclang.compiler.driver.program { JacProgram }

glob SymId: TypeAlias = int,
     DataflowTransfer: TypeAlias = Callable[[UniCFGNode, set[SymId]], set[SymId]];

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

glob _STR_MANGLES: frozenset[str] = frozenset(["str", "LiteralString"]);

def _stdlib_attr_call_root(call: FuncCall) -> (str | None);

obj BorrowMeta {
    has name: str,
        owner: (SymId | None) = None,
        is_mut: bool = False,
        extra_owners: list[SymId] postinit,
        field: str = "";

    def postinit {
        self.extra_owners = [];
    }
}

walker OwnershipCheckPass(Transform) {
    has prog: JacProgram,
        ir_in: Module,
        cancel_token: any = None,
        owned_decl: dict[SymId, Name] = {},
        linear_decl: dict[SymId, Name] = {},
        consumed_syms: set[SymId] = set(),
        borrow_meta: dict[SymId, BorrowMeta] = {},
        e1304_borrow_ids: set[SymId] = set(),
        in_consumed: dict[int, set[SymId]] = {},
        in_live_borrows: dict[int, set[SymId]] = {},
        in_reaching_borrows: dict[int, set[SymId]] = {},
        consumed_at: dict[SymId, UniNode] = {},
        borrow_created_at: dict[SymId, UniNode] = {},
        idx_assignments: list[Assignment] = [],
        idx_names: list[Name] = [],
        idx_params: list[ParamVar] = [],
        idx_returns: list[ReturnStmt] = [],
        idx_concurrent: list[ConcurrentExpr] = [],
        name_uses_by_sym: dict[SymId, list[Name]] = {},
        imm_decl: dict[SymId, Name] = {},
        view_syms: set[SymId] = set(),
        view_elision_fns: dict[int, int] = {},
        nogc_prov: (str | None) = None,
        receiver_modes: dict[int, OwnershipKind] = {},
        receiver_probe: set[int] = set(),
        arch_view_syms: set[SymId] = set();

    static has PROVIDES: tuple = ('ownership', ),
        REQUIRES: tuple = ('CfgSucc', 'TypeOf'),
        HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _nogc_setup -> None;
    def _nogc_resolve_provenance -> (str | None);
    def _nogc_infer_locals -> None;
    def _nogc_infer_state(expr: Expr | None) -> tuple[OwnershipKind, list[Name]];
    def _nogc_bind_inferred(
        nd: Assignment, tgt: Name, kind: OwnershipKind, roots: list[Name]
    ) -> None;

    def _nogc_type_is_str(expr: Expr | None) -> bool;
    def _nogc_place_text(expr: Expr | None) -> str;
    def _nogc_elem_fixit(elem: Expr | None, dest: str, verb: str) -> tuple[str, str];
    def _name_written_through(nm: Name) -> bool;
    def _emit_place_intrinsic_diagnostics -> None;
    def _check_mutating_receiver(recv: Name, call: FuncCall, method: str) -> None;
    def _is_builtin_mutator(ability: Ability | None) -> bool;
    def _trailer_writes_root(top: UniNode) -> bool;
    def _nogc_str_slice_value(expr: Expr | None) -> bool;
    def _view_base_place(expr: Expr | None) -> (Name | None);
    def _view_root_owner(sym_id: SymId) -> SymId;
    def _sym_is_param(sym_id: SymId) -> bool;
    def _view_of_expr(expr: Expr | None) -> (SymId | None);
    def _stamp_view_borrows -> None;
    def _view_arch_of_call(call: FuncCall) -> (Archetype | None);
    def _is_view_expr(expr: Expr | None) -> bool;
    def _view_ctor_owners(expr: Expr | None) -> (list[SymId] | None);
    def _derivation_root(base: Name) -> (SymId | None);
    def _stamp_arch_view_bindings -> None;
    def _borrow_owners_of(borrow_id: SymId) -> list[SymId];
    def _stamp_view_call_results(scope: UniNode, seen_ids: set[int]) -> None;
    def _view_call_owner(call: FuncCall) -> (SymId | None);
    def _emit_view_diagnostics -> None;
    def _nogc_str_elem_ok(expr: Expr | None, idx_ctx: bool = False) -> bool;
    def _nogc_tag_shape(tag: SubTag | None) -> str;
    def _nogc_local_shape(nm: Name) -> str;
    def _nogc_local_shape_expr_heap(expr: Expr | None) -> bool;
    def _nogc_expr_type_is_heap(expr: Expr | None) -> bool;
    def _expr_scalar_typed(expr: Expr | None) -> bool;
    def _nogc_is_container_expr(expr: Expr | None) -> bool;
    def _nogc_is_list_expr(expr: Expr | None) -> bool;
    def _nogc_container_grow_method(call: FuncCall) -> (str | None);
    def _nogc_module_enforced(mod_name: str) -> bool;
    def _nogc_check_call(call: FuncCall, prov: str) -> None;
    def _own_field_target(tgt: AtomTrailer) -> bool;
    def _nogc_fresh_arch_elem(expr: Expr | None) -> bool;
    def _nogc_fresh_scalar_list(expr: Expr | None) -> bool;
    def _stamp_loop_borrows -> None;
    def _emit_element_space_conflicts -> None;
    def _emit_freeze_diagnostics -> None;
    def _emit_seal_warnings -> None;
    def _flow_lend_joined(cexpr: ConcurrentExpr, owner_sid: SymId) -> bool;
    def _spawn_move_gen(nd: UniCFGNode) -> set[SymId];
    def _emit_enforcement_diagnostics -> None;
    def _build_index(tree: UniNode) -> None;
    def _stamp_ownership -> None;
    def _stamp_overwrite_consumed -> None;
    def _stamp_move_sites -> None;
    def _receiver_mode(ability: Ability | None) -> OwnershipKind;
    def _explicit_receiver_mode(ability: Ability) -> (OwnershipKind | None);
    def _method_writes_self(ability: Ability) -> bool;
    def _self_method_callees(ability: Ability) -> list[Ability];
    def _stamp_receiver_modes -> None;
    def _stamp_raises_effects -> None;
    def _raise_type_name(nd: RaiseStmt) -> (str | None);
    def _handled_by_enclosing_try(nd: UniNode, exc: str, stop: UniNode) -> bool;
    def _callee_ability(call: FuncCall) -> (Ability | None);
    def _local_raises(ab: UniNode) -> set[str];
    def _emit_raises_diagnostics -> None;
    def _is_consuming_receiver(nd: Name) -> bool;
    def _method_call_receiver(call: FuncCall) -> (Name | None);
    def _method_call_mode(call: FuncCall) -> OwnershipKind;
    def _emit_receiver_diagnostics -> None;
    def _owned_field_of(expr: Expr | None) -> (Name | None);
    def _owned_index_of(expr: Expr | None) -> (Name | None);
    def _place_text(expr: Expr) -> str;
    def _emit_place_move(expr: Expr) -> None;
    def _callee_own_param_names(call: FuncCall) -> (set[str] | None);
    def _emit_place_move_diagnostics -> None;
    def _emit_linear_diagnostics(cfg_nodes: list[UniCFGNode]) -> None;
    def _node_within(nd: UniNode, scope: UniNode) -> bool;
    def _is_scope_exit(nd: UniCFGNode) -> bool;
    def _call_consumes_args(call: FuncCall) -> bool;
    def _grow_arg_moves(call: FuncCall, arg: Expr | None) -> bool;
    def _nogc_moved_arch_elem(expr: Expr | None) -> bool;
    def _has_region_blocks -> bool;
    def _emit_region_escape_diagnostics -> None;
    def _emit_sendability_diagnostics -> None;
    def _is_deep_immutable_scalar(nm: Name) -> bool;
    def _emit_marker_diagnostics -> None;
    def _emit_imm_mutation(sid: SymId, site: UniNode, decl: Name | None) -> None;
    def _return_roots_at_param_borrow(nd: Expr | None) -> bool;
    def _borrow_region(sym_id: SymId) -> (UniScopeNode | None);
    def _region_strictly_outlives(
        dest: UniScopeNode | None, region: UniScopeNode | None
    ) -> bool;

    def _place_of(nd: Expr | None) -> (Name | None);
    def _places_reachable(nd: Expr | None) -> list[Name];
    def _region_escapee_roots(expr: Expr | None, region: OpenStmt) -> list[Name];
    def _is_region_local(nd: Name, region: OpenStmt) -> bool;
    def _emit_region_escape(nm: Name, region: OpenStmt) -> None;
    def _region_expr_is_scalar(expr: Expr | None) -> bool;
    def _region_callee_is_safe(call: FuncCall, region: OpenStmt) -> bool;
    def _region_call_result_rooted(
        expr: Expr | None, region: OpenStmt, hsid: SymId | None
    ) -> bool;

    def _emit_region_call_escape(call: Expr, region: OpenStmt) -> None;
    def _stamp_region_borrows -> None;
    def _open_handle_name(region: OpenStmt) -> (Name | None);
    def _seal_connect_handle(bx: BinaryExpr) -> (Name | None);
    def _flow_for_stmts -> list[InForStmt];
    def _emit_flow_for_diagnostics -> None;
    def _chunks_shape_of(expr: Expr | None) -> (tuple | None);
    def _emit_chunk_view_diagnostics -> None;
    def _flow_reduce_shape(asgn: Assignment, sid: SymId) -> str;
    def _collect_flow_reductions(lp: InForStmt) -> dict[SymId, str];
    def _process_partition_sugar -> None;
    def _partition_sugar_reason(call: FuncCall) -> str;
    def _seal_arch_ctor(fc: FuncCall) -> bool;
    def _emit_post_seal_diagnostics(region: OpenStmt) -> None;
    def _region_handle_sid(region: OpenStmt) -> (SymId | None);
    def _region_handle_kind(region: OpenStmt) -> str;
    def _param_is_region_borrow(param: ParamVar) -> bool;
    def _region_param_count(region: OpenStmt) -> int;
    def _call_borrows_handle(expr: Expr | None, hsid: SymId) -> bool;
    def _is_own_decl(nd: Assignment) -> (Name | None);
    def _is_borrow_decl(nd: Assignment) -> (Name | None);
    def _borrow_target(nd: Assignment) -> (Name | None);
    def _borrow_source_owner(nd: Assignment) -> (Name | None);
    def _assign_kill_gen(nd: Assignment) -> tuple[set[SymId], set[SymId]];
    def _cfg_owner(sub: UniNode) -> (UniCFGNode | None);
    def _call_move_gen(nd: UniCFGNode) -> set[SymId];
    def _return_move_gen(nd: UniCFGNode) -> set[SymId];
    def _solve_forward_dataflow(
        cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
    ) -> dict[int, set[SymId]];

    def _solve_backward_dataflow(
        cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
    ) -> dict[int, set[SymId]];

    def _transfer(nd: UniCFGNode, in_set: set[SymId]) -> set[SymId];
    def _run_dataflow(cfg_nodes: list[UniCFGNode]) -> None;
    def _borrow_read_gen(nd: UniCFGNode) -> set[SymId];
    def _borrow_assign_kill_gen(nd: UniCFGNode) -> tuple[set[SymId], set[SymId]];
    def _reaching_transfer(nd: UniCFGNode, in_set: set[SymId]) -> set[SymId];
    def _live_transfer(nd: UniCFGNode, out_set: set[SymId]) -> set[SymId];
    def _run_borrow_liveness(cfg_nodes: list[UniCFGNode]) -> None;
    def _run_reaching_borrows(cfg_nodes: list[UniCFGNode]) -> None;
    def _active_borrows_at(cfg: UniCFGNode) -> set[SymId];
    def _is_ancestor(ancestor: UniNode, nd: UniNode) -> bool;
    def _emit_diagnostics -> None;
    def _earlier_move_in_node(nd: Name, sid: SymId) -> (Name | None);
    def _emit_borrow_diagnostics -> None;
    def _consumed_gen_at(nd: UniCFGNode) -> set[SymId];
    def _emit_move_while_borrowed(cfg_nodes: list[UniCFGNode]) -> None;
    def _emit_escape_diagnostics -> None;
    def _escaping_borrow_owner(nd: Expr | None) -> (str | None);
    def _owner_decl_related(
        borrow_id: (SymId | None), owner_name: str
    ) -> (list[tuple[str, UniNode]] | None);

    def _sym_id(nd: UniNode | None) -> (SymId | None);
    def _name_sym_id(nd: Name) -> SymId;
    def _owned_sym_of(nd: UniNode | None) -> (SymId | None);
    def _owned_sym_of_expr(nd: Expr | None) -> (SymId | None);
    def _borrow_sym_of(nd: UniNode | None) -> (SymId | None);
    def _owned_name(sym_id: SymId, fallback: str) -> str;
    def _borrow_owner_of(borrow_id: SymId) -> (SymId | None);
    def _borrow_is_mut_of(borrow_id: SymId) -> bool;
    def _borrow_field_of(borrow_id: SymId) -> str;
    def _single_field_of(nd: Expr | None) -> str;
    def _fields_overlap(a: str, b: str) -> bool;
    def _borrow_display_name(borrow_id: SymId, fallback: str) -> str;
    def _classify_access(nd: Name) -> AccessKind;
    def _is_write_target(nd: Name) -> bool;
    def _is_read_name(nd: Name) -> bool;
    def _is_move_producing_use(nd: Name) -> bool;
    def _target_owner_sym(nd: Expr) -> (SymId | None);
    def _call_params(call: FuncCall) -> Sequence[Expr | KWPair];
}
