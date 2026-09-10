import from typing { cast }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AssertStmt,
    AstElseBodyNode,
    AtomUnit,
    AwaitingClause,
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
    LambdaExpr,
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
import from jaclang.compiler.passes.uni_pass { UniPass }

walker CFGBuildPass(UniPass) {
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

    def _next_in_body(
        body: Sequence[CodeBlockStmt], child: UniNode
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

    can cfg_collect_affected with UniNode entry;
    can enter_if_stmt with IfStmt entry;
    can enter_else_if with ElseIf entry;
    can enter_assert_stmt with AssertStmt entry;
    can enter_match_stmt with MatchStmt entry;
    can exit_bool_expr with BoolExpr exit;
    can exit_if_else_expr with IfElseExpr exit;
    can exit_if_stmt with IfStmt exit;
    def _exit_if_stmt_impl(nd: IfStmt) -> None;
    can exit_else_if with ElseIf exit;
    can exit_else_stmt with ElseStmt exit;
    can exit_while_stmt with WhileStmt exit;
    can exit_forever_stmt with ForeverStmt exit;
    can exit_in_for_stmt with InForStmt exit;
    can exit_iter_for_stmt with IterForStmt exit;
    can exit_list_compr with ListCompr exit;
    can exit_set_compr with SetCompr exit;
    can exit_gen_compr with GenCompr exit;
    can exit_dict_compr with DictCompr exit;
    def _wire_compr_filters(target_node: UniCFGNode, comprs: list[InnerCompr]) -> None;
    can exit_ctrl_stmt with CtrlStmt exit;
    can exit_try_stmt with TryStmt exit;
    can exit_except with Except exit;
    can exit_finally_stmt with FinallyStmt exit;
    can exit_match_stmt with MatchStmt exit;
    can exit_match_case with MatchCase exit;
    can exit_switch_stmt with SwitchStmt exit;
    can exit_switch_case with SwitchCase exit;
    can exit_with_stmt with WithStmt exit;
    can exit_typed_ctx_block with TypedCtxBlock exit;
    can exit_open_stmt with OpenStmt exit;
    can exit_jsx_slot with JsxSlot exit;
    can exit_ability with Ability exit;
    can exit_archetype with Archetype exit;
    can exit_impl_def with ImplDef exit;
    can exit_module_code with ModuleCode exit;
    can exit_test with Test exit;
}

walker CoalesceBBPass(UniPass) {
    has basic_blocks: dict[int, dict[str, list[UniCFGNode]]] = {},
        bb_counter: int = 0;

    def before_pass -> None;
    def get_bb(nd: UniCFGNode) -> list[UniCFGNode];
    can coalesce_collect with UniNode entry;
    def printgraph_cfg -> str;
    def _node_label(nd: UniNode) -> str;
    def _has_bool_sc(condition: Expr) -> bool;
}

def _is_structural_child(nd: UniNode) -> bool;
def cfg_dot_from_file(file_name: str) -> str;
