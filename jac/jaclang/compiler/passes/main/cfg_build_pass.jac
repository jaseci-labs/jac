import from collections.abc { Sequence }
import from typing { cast }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import type from jaclang.jac0core.program { JacProgram }

obj CFGBuildPass(UniPass) {
    static has PROVIDES: tuple = ('cfg', );

    def before_pass -> None;
    def link_bbs(source: uni.UniCFGNode, target: uni.UniCFGNode) -> None;
    def _link_sequential(body: Sequence[uni.CodeBlockStmt]) -> None;
    def _connect_tails(parent: uni.UniNode, target: uni.UniCFGNode) -> None;
    def _link_body_tails_to_header(
        nd: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt
    ) -> None;

    def _is_terminal(nd: uni.UniNode) -> bool;
    def _find_parent_of_types(
        nd: uni.UniNode, types: tuple[type[uni.UniCFGNode], ...]
    ) -> (uni.UniCFGNode | None);

    def _find_next_cfg_stmt_after(
        parent: uni.UniNode, child: uni.UniNode
    ) -> (uni.UniCFGNode | None);

    def _wire_bool_operands(
        values: list[uni.CfgExpr],
        op_is_and: bool,
        true_target: (uni.UniCFGNode | None),
        false_target: (uni.UniCFGNode | None)
    ) -> uni.CfgExpr;

    def _set_and_link(
        cfg: uni.CfgExpr,
        true_target: (uni.UniCFGNode | None),
        false_target: (uni.UniCFGNode | None)
    ) -> None;

    def _patch_inner_bool(
        nested: uni.BoolExpr,
        my_true: (uni.UniCFGNode | None),
        my_false: (uni.UniCFGNode | None)
    ) -> None;

    def enter_node(nd: uni.UniNode) -> None;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_else_if(nd: uni.ElseIf) -> None;
    def enter_assert_stmt(nd: uni.AssertStmt) -> None;
    def enter_match_stmt(nd: uni.MatchStmt) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_forever_stmt(nd: uni.ForeverStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def exit_list_compr(nd: uni.ListCompr) -> None;
    def exit_set_compr(nd: uni.SetCompr) -> None;
    def exit_gen_compr(nd: uni.GenCompr) -> None;
    def exit_dict_compr(nd: uni.DictCompr) -> None;
    def _wire_compr_filters(
        target_node: uni.UniCFGNode, comprs: list[uni.InnerCompr]
    ) -> None;

    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def exit_try_stmt(nd: uni.TryStmt) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_finally_stmt(nd: uni.FinallyStmt) -> None;
    def exit_match_stmt(nd: uni.MatchStmt) -> None;
    def exit_match_case(nd: uni.MatchCase) -> None;
    def exit_switch_stmt(nd: uni.SwitchStmt) -> None;
    def exit_switch_case(nd: uni.SwitchCase) -> None;
    def exit_with_stmt(nd: uni.WithStmt) -> None;
    def exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    def exit_region_stmt(nd: uni.RegionStmt) -> None;
    def exit_jsx_slot(nd: uni.JsxSlot) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def exit_module_code(nd: uni.ModuleCode) -> None;
    def exit_test(nd: uni.Test) -> None;
}

obj CoalesceBBPass(UniPass) {
    has basic_blocks: dict[int, dict[str, list[uni.UniCFGNode]]] = {},
        bb_counter: int = 0;

    def before_pass -> None;
    def get_bb(nd: uni.UniCFGNode) -> list[uni.UniCFGNode];
    def enter_node(nd: uni.UniNode) -> None;
    def printgraph_cfg -> str;
    def _node_label(nd: uni.UniNode) -> str;
    def _has_bool_sc(condition: uni.Expr) -> bool;
}

def _is_structural_child(nd: uni.UniNode) -> bool;
def cfg_dot_from_file(file_name: str) -> str;
