"""Control flow graph build pass for the Jac compiler.

This pass constructs a control flow graph (CFG) representation of the program by:
1. Identifying basic blocks (sequences of statements with a single entry and exit point)
2. Establishing control flow relationships between these blocks
3. Tracking loop structures and maintaining proper nesting relationships
4. Building connections between statements that affect control flow (conditionals, loops, etc.)

The CFG provides a foundation for data flow analysis, optimization, and understanding program execution paths.
The pass also includes functionality to coalesce basic blocks and generate visual representations of the CFG.
"""
import from collections.abc { Sequence }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }

"""Jac Symbol table build pass."""
class CFGBuildPass(UniPass) {
    def before_pass(self: CFGBuildPass) -> None;
    def push_loop_stack(self: CFGBuildPass, loop_header: uni.UniCFGNode) -> None;
    def pop_loop_stack(self: CFGBuildPass, <>node: uni.UniCFGNode) -> None;
    def get_parent_bb_stmt(
        self: CFGBuildPass, <>node: uni.UniCFGNode
    ) -> (uni.UniCFGNode | None);

    def link_bbs(
        self: CFGBuildPass, source: uni.UniCFGNode, target: uni.UniCFGNode
    ) -> None;

    def get_code_block_sequence(
        self: CFGBuildPass, <>node: (uni.UniNode | None)
    ) -> (list[uni.UniCFGNode] | None);

    def enter_node(self: CFGBuildPass, <>node: uni.UniNode) -> None;
    def exit_node(self: CFGBuildPass, <>node: uni.UniNode) -> None;
    def after_pass(self: CFGBuildPass) -> None;
}

"""Fetch basic blocks."""
class CoalesceBBPass(UniPass) {
    def before_pass(self: CoalesceBBPass) -> None;
    def get_bb(self: CoalesceBBPass, <>node: uni.UniCFGNode) -> list[uni.UniCFGNode];
    def enter_node(self: CoalesceBBPass, <>node: uni.UniNode) -> None;
    def printgraph_cfg(self: CoalesceBBPass) -> str;
}

def cfg_dot_from_file(file_name: str) -> str;
