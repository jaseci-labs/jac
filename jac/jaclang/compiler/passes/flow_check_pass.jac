import from typing { cast }

obj NodeEffect {
    has always: set[SymId] = set(),
        branch: bool = False,
        on_true: set[SymId] = set(),
        on_false: set[SymId] = set(),
        true_entry: (UniCFGNode | None) = None,
        body_entry: (UniCFGNode | None) = None,
        into_body: set[SymId] = set(),
        kills: set[SymId] = set();
}

obj FrameFlow {
    has owner: UniNode,
        start: UniCFGNode,
        scope: (UniScopeNode | None),
        nodes: list[UniCFGNode] = [],
        members: set[int] = set(),
        tracked: set[SymId] = set(),
        effects: dict[int, NodeEffect] = {},
        state: dict[int, set[SymId]] = {},
        finally_state: dict[int, dict[int, set[SymId]]] = {},
        succ_memo: dict[int, list[UniCFGNode]] = {};
}

walker FlowCheckPass(CompilerPass) {
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _frames(flat: list[UniNode]) -> list[UniCFGNode];
    def _frame_body(owner: UniNode) -> (Sequence[UniNode] | None);
    def _frame_of(nd: UniNode) -> (UniNode | None);
    def _is_flow_node(nd: UniCFGNode) -> bool;
    def _first_flow(fr: FrameFlow, body: Sequence[UniNode]) -> (UniCFGNode | None);
    def _build_frame(
        start: UniCFGNode, by_owner: dict[int, list[UniCFGNode]]
    ) -> (FrameFlow | None);

    def _successors(fr: FrameFlow, nd: UniCFGNode) -> list[UniCFGNode];
    def _transfer(
        fr: FrameFlow, pred: UniCFGNode, succ: UniCFGNode, in_set: set[SymId]
    ) -> set[SymId];

    def _check_frame(fr: FrameFlow) -> None;
    def _solve_finally_bodies(fr: FrameFlow) -> None;
    def _check_defaults(fr: FrameFlow) -> None;
    def _encloses(outer: UniNode, nd: UniNode) -> bool;
    def _effect(
        fr: FrameFlow, nd: UniCFGNode, da: set[SymId], check: bool
    ) -> NodeEffect;

    def _read_state(fr: FrameFlow, nd: UniCFGNode) -> set[SymId];
    def _eval(
        fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
    ) -> tuple[set[SymId], set[SymId]];

    def _eval_all(
        fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
    ) -> set[SymId];

    def _eval_kids(
        fr: FrameFlow, nd: UniNode, da: set[SymId], check: bool
    ) -> set[SymId];

    def _eval_bool(
        fr: FrameFlow, nd: BoolExpr, da: set[SymId], check: bool
    ) -> tuple[set[SymId], set[SymId]];

    def _eval_compr(
        fr: FrameFlow,
        nd: UniNode,
        comprs: list[InnerCompr],
        da: set[SymId],
        check: bool
    ) -> set[SymId];

    def _bind_target(
        fr: FrameFlow, target: UniNode, da: set[SymId], check: bool
    ) -> set[SymId];

    def _eval_pattern(
        fr: FrameFlow, pat: UniNode, da: set[SymId], check: bool
    ) -> set[SymId];

    def _eval_assignment(
        fr: FrameFlow, nd: Assignment, da: set[SymId], check: bool
    ) -> set[SymId];

    def _sym_of(fr: FrameFlow, nd: UniNode) -> (SymId | None);
    def _read(fr: FrameFlow, nm: NameAtom, da: set[SymId], check: bool) -> None;
}
