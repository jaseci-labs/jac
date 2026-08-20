import from typing { cast }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    AssertStmt,
    AstElseBodyNode,
    AtomUnit,
    BoolExpr,
    CfgExpr,
    CodeBlockStmt,
    CtrlStmt,
    DictCompr,
    DisengageStmt,
    ElseIf,
    ElseStmt,
    Except,
    Expr,
    FinallyStmt,
    ForeverStmt,
    GenCompr,
    GlobalVars,
    IfElseExpr,
    IfStmt,
    ImplDef,
    InForStmt,
    InnerCompr,
    IterForStmt,
    JsxSlot,
    ListCompr,
    MatchCase,
    MatchStmt,
    ModuleCode,
    Name,
    OpenStmt,
    RaiseStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SwitchCase,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TypeAlias,
    TypedCtxBlock,
    UniCFGNode,
    UniNode,
    WhileStmt,
    WithStmt
}
import from jaclang.jac0core.passes.uni_pass { UniPass }
import type from jaclang.jac0core.program { JacProgram }

obj CFGBuildPass(UniPass) {
    static has PROVIDES: tuple = ('cfg', );

    def before_pass -> None;
    def link_bbs(source: UniCFGNode, target: UniCFGNode) -> None;
    def _link_sequential(body: Sequence[CodeBlockStmt]) -> None;
    def _exit_wired(nd: UniCFGNode) -> bool;
    def _connect_tails(parent: UniNode, target: UniCFGNode) -> None;
    def _link_body_tails_to_header(
        nd: WhileStmt | ForeverStmt | InForStmt | IterForStmt
    ) -> None;

    def _is_terminal(nd: UniNode) -> bool;
    def _find_parent_of_types(
        nd: UniNode, types: tuple[type[UniCFGNode], ...]
    ) -> (UniCFGNode | None);

    def _find_next_cfg_stmt_after(
        parent: UniNode, child: UniNode
    ) -> (UniCFGNode | None);

    def _find_next_cfg_stmt_after_branch(nd: UniNode) -> (UniCFGNode | None);
    def _wire_bool_operands(
        values: list[CfgExpr],
        op_is_and: bool,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> CfgExpr;

    def _wire_bool_chain(
        values: list[CfgExpr],
        op_is_and: bool,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> CfgExpr;

    def _set_and_link(
        cfg: CfgExpr,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> None;

    def enter_node(nd: UniNode) -> None;
    def enter_if_stmt(nd: IfStmt) -> None;
    def enter_else_if(nd: ElseIf) -> None;
    def enter_assert_stmt(nd: AssertStmt) -> None;
    def enter_match_stmt(nd: MatchStmt) -> None;
    def exit_bool_expr(nd: BoolExpr) -> None;
    def exit_if_else_expr(nd: IfElseExpr) -> None;
    def exit_if_stmt(nd: IfStmt) -> None;
    def exit_else_if(nd: ElseIf) -> None;
    def exit_else_stmt(nd: ElseStmt) -> None;
    def exit_while_stmt(nd: WhileStmt) -> None;
    def exit_forever_stmt(nd: ForeverStmt) -> None;
    def exit_in_for_stmt(nd: InForStmt) -> None;
    def exit_iter_for_stmt(nd: IterForStmt) -> None;
    def exit_list_compr(nd: ListCompr) -> None;
    def exit_set_compr(nd: SetCompr) -> None;
    def exit_gen_compr(nd: GenCompr) -> None;
    def exit_dict_compr(nd: DictCompr) -> None;
    def _wire_compr_filters(target_node: UniCFGNode, comprs: list[InnerCompr]) -> None;
    def exit_ctrl_stmt(nd: CtrlStmt) -> None;
    def exit_try_stmt(nd: TryStmt) -> None;
    def exit_except(nd: Except) -> None;
    def exit_finally_stmt(nd: FinallyStmt) -> None;
    def exit_match_stmt(nd: MatchStmt) -> None;
    def exit_match_case(nd: MatchCase) -> None;
    def exit_switch_stmt(nd: SwitchStmt) -> None;
    def exit_switch_case(nd: SwitchCase) -> None;
    def exit_with_stmt(nd: WithStmt) -> None;
    def exit_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def exit_open_stmt(nd: OpenStmt) -> None;
    def exit_jsx_slot(nd: JsxSlot) -> None;
    def exit_ability(nd: Ability) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def exit_module_code(nd: ModuleCode) -> None;
    def exit_test(nd: Test) -> None;
}

obj CoalesceBBPass(UniPass) {
    has basic_blocks: dict[int, dict[str, list[UniCFGNode]]] = {},
        bb_counter: int = 0;

    def before_pass -> None;
    def get_bb(nd: UniCFGNode) -> list[UniCFGNode];
    def enter_node(nd: UniNode) -> None;
    def printgraph_cfg -> str;
    def _node_label(nd: UniNode) -> str;
    def _has_bool_sc(condition: Expr) -> bool;
}

def _is_structural_child(nd: UniNode) -> bool;
def cfg_dot_from_file(file_name: str) -> str;
