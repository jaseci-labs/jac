"""Control flow graph build pass for the Jac compiler.

This pass constructs a control flow graph (CFG) by establishing bb_in/bb_out
edges between UniCFGNode AST nodes using an entry/exit visitor pattern.

Each node's exit handler connects it to its CFG children (outgoing edges).
Incoming edges are set by the parent node's exit handler via sequential linking.
The entry handlers collect affected_symbols for the Pyright-style branch-skipping
optimization used during backward CFG walks in type narrowing.
"""
import from collections.abc { Sequence }
import from threading { Event }
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

"""CFG build pass using entry/exit visitor pattern."""
obj CFGBuildPass(UniPass) {
    def before_pass -> None;
    # -- Utilities --
    def link_bbs(source: uni.UniCFGNode, target: uni.UniCFGNode) -> None;
    def _link_sequential(body: Sequence[uni.CodeBlockStmt]) -> None;
    def _connect_tails(parent: uni.UniNode, target: uni.UniCFGNode) -> None;
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

    # -- Symbol collection (enter) --
    def enter_node(nd: uni.UniNode) -> None;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_else_if(nd: uni.ElseIf) -> None;
    def enter_assert_stmt(nd: uni.AssertStmt) -> None;
    def enter_match_stmt(nd: uni.MatchStmt) -> None;
    # -- Edge building (exit) --
    # Expression-level CFG
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    # Branch
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    # Loop
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    # Control flow
    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    # Exception
    def exit_try_stmt(nd: uni.TryStmt) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_finally_stmt(nd: uni.FinallyStmt) -> None;
    # Multi-branch
    def exit_match_stmt(nd: uni.MatchStmt) -> None;
    def exit_match_case(nd: uni.MatchCase) -> None;
    def exit_switch_stmt(nd: uni.SwitchStmt) -> None;
    def exit_switch_case(nd: uni.SwitchCase) -> None;
    # Other
    def exit_with_stmt(nd: uni.WithStmt) -> None;
    def exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    # Scope boundaries
    def exit_ability(nd: uni.Ability) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def exit_module_code(nd: uni.ModuleCode) -> None;
    def exit_test(nd: uni.Test) -> None;
}

"""Fetch basic blocks."""
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
