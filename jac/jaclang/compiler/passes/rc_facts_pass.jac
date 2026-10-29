enum Ownership {
    OWNED = "owned",
    BORROWED = "borrowed",
    STATIC = "static",
    UNKNOWN = "unknown"
}

def method_returns_borrow(callee: (Ability | None)) -> bool;

def call_borrows_receiver(call: FuncCall) -> bool;

def result_ownership(expr: (Expr | None)) -> Ownership;

def loop_body_locals(body: (Sequence[UniNode] | None)) -> list[str];

walker RcFactsPass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.CFG_SUCC, ), provides=(AnalysisFact.RC_FACTS, )
    );

    has _node_use: dict[int, set[SymId]] = {},
        _node_def: dict[int, set[SymId]] = {};

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _stamp_param_rebound(ir_in: Module) -> None;
    def _stamp_escapes(ir_in: Module) -> None;
    def _call_use_stack_safe(nm: NameAtom, sym: Symbol) -> bool;
    def _borrow_arg_callee_ok(bx: UnaryExpr) -> bool;
    def _scalar_attr_read(nm: NameAtom) -> bool;
    def _stamp_region_handles(ir_in: Module) -> None;
    def _asn_makes_region_handle(nd: Assignment) -> bool;
    def _use_ok_for_stack(nm: NameAtom) -> bool;
    def _enclosing_fn_scope(
        nd: UniNode, stop_at_comprehension: bool = False
    ) -> UniNode | None;

    def _is_param_sym(sym: Symbol) -> bool;
    def _last_use_tracked(sym: Symbol) -> bool;
    def _stamp_last_use(ir_in: Module) -> None;
    def _stamp_scope_cleanup(ir_in: Module) -> None;
    def _stamp_move_in(ir_in: Module) -> None;
    def _repeats_in_comprehension(use: NameAtom) -> bool;
    def _collect_last_use(
        owner: UniNode, body: Sequence[UniNode], out: dict[int, list[str]]
    ) -> None;

    def _binds_local_name(nm: Name) -> bool;
    def _stamp_move_lowerable(ir_in: Module) -> None;
    def _cfg_owner(sub: UniNode) -> (UniCFGNode | None);
    def _is_def_name(nm: NameAtom) -> bool;
    def _is_alias_value(nm: Name) -> bool;
    def _move_flow_safe(uses: list[Name], sites: list[Assignment]) -> bool;
    def _move_candidate_source(nd: Assignment) -> (Name | None);
    def _solve_liveness(
        cfg_nodes: list[UniCFGNode], tracked: set[SymId]
    ) -> dict[int, set[SymId]];
}
