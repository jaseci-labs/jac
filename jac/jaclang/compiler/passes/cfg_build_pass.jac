import from typing { cast }

walker CFGBuildPass(TreePass) {
    def link_bbs(source: UniCFGNode, target: UniCFGNode) -> None;
    def _is_exit_target(source: UniCFGNode, target: UniCFGNode) -> bool;
    def _link_to(source: UniCFGNode, target: (UniCFGNode | None)) -> None;
    def _is_terminal(nd: UniNode) -> bool;
    def _stmt_body(parent: UniNode) -> (Sequence[UniNode] | None);
    def _is_flow_frame(nd: UniNode) -> bool;
    def _in_stmt_body(nd: UniNode) -> bool;
    def _next_in_body(body: Sequence[UniNode], child: UniNode) -> (UniCFGNode | None);
    def _follow(nd: UniNode) -> (UniCFGNode | None);
    def _body_entry(
        body: Sequence[UniNode], fallback: (UniCFGNode | None)
    ) -> (UniCFGNode | None);

    def _else_entry(nd: UniNode) -> (UniCFGNode | None);
    def _break_target(nd: CtrlStmt) -> (UniCFGNode | None);
    def _is_compound(nd: UniNode) -> bool;
    def _is_irrefutable_case(nd: MatchCase) -> bool;
    def _wire_branch(
        nd: UniCFGNode,
        condition: Expr,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> None;

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
    can exit_simple_stmt with UniCFGNode exit;
    can exit_bool_expr with BoolExpr exit;
    can exit_if_else_expr with IfElseExpr exit;
    can exit_if_stmt with IfStmt exit;
    can exit_while_stmt with WhileStmt exit;
    can exit_forever_stmt with ForeverStmt exit;
    can exit_in_for_stmt with InForStmt exit;
    can exit_iter_for_stmt with IterForStmt exit;
    can exit_list_compr with ListCompr exit;
    can exit_set_compr with SetCompr exit;
    can exit_gen_compr with GenCompr exit;
    can exit_dict_compr with DictCompr exit;
    def _wire_compr_filters(target_node: UniCFGNode, comprs: list[InnerCompr]) -> None;
    def _link_on_pass(step: UniCFGNode, nxt: UniCFGNode) -> None;
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
    can exit_visit_stmt with VisitStmt exit;
    can exit_jsx_slot with JsxSlot exit;
    can exit_lambda_expr with LambdaExpr exit;
    can exit_ability with Ability exit;
    can exit_archetype with Archetype exit;
    can exit_impl_def with ImplDef exit;
    can exit_test with Test exit;
}

def is_structural_child(nd: UniNode) -> bool;

def is_constant_true(expr: Expr) -> bool;

def is_abrupt_entry(pred: UniCFGNode, succ: UniCFGNode) -> bool;

def falls_off_end(
    frame: UniCFGNode, live: Callable[[UniCFGNode, UniCFGNode], bool]
) -> bool;

def _unwrap_parens(expr: Expr) -> Expr;

def unwrap_to_bool(cfg: CfgExpr) -> BoolExpr | None;

def _bool_is_and(expr: BoolExpr) -> bool;
