"""Abstract class for IR Passes for Jac."""

from __future__ import annotations

from typing import Optional, TYPE_CHECKING, Type, TypeVar

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.transform import Transform
from jaclang.utils.helpers import pascal_to_snake

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram

T = TypeVar("T", bound=uni.UniNode)


class UniPass(Transform[uni.Module, uni.Module]):
    """Abstract class for IR passes."""

    def __init__(
        self,
        ir_in: uni.Module,
        prog: JacProgram,
    ) -> None:
        """Initialize parser."""
        self.term_signal = False
        self.prune_signal = False
        Transform.__init__(self, ir_in, prog)

    def before_pass(self) -> None:
        """Run once before pass."""

    def after_pass(self) -> None:
        """Run once after pass."""

    def enter_node(self, node: uni.UniNode) -> None:
        """Run on entering node."""
        if hasattr(self, f"enter_{pascal_to_snake(type(node).__name__)}"):
            getattr(self, f"enter_{pascal_to_snake(type(node).__name__)}")(node)

    def exit_node(self, node: uni.UniNode) -> None:
        """Run on exiting node."""
        if hasattr(self, f"exit_{pascal_to_snake(type(node).__name__)}"):
            getattr(self, f"exit_{pascal_to_snake(type(node).__name__)}")(node)

    def terminate(self) -> None:
        """Terminate traversal."""
        self.term_signal = True

    def prune(self) -> None:
        """Prune traversal."""
        self.prune_signal = True

    @staticmethod
    def get_all_sub_nodes(
        node: uni.UniNode, typ: Type[T], brute_force: bool = False
    ) -> list[T]:
        """Get all sub nodes of type."""
        result: list[T] = []
        # Assumes pass built the sub node table
        if not node:
            return result
        elif len(node._sub_node_tab):
            if typ in node._sub_node_tab:
                for i in node._sub_node_tab[typ]:
                    if isinstance(i, typ):
                        result.append(i)
        elif len(node.kid):
            if not brute_force:
                raise ValueError(f"Node has no sub_node_tab. {node}")
            # Brute force search
            else:
                for i in node.kid:
                    if isinstance(i, typ):
                        result.append(i)
                    result.extend(UniPass.get_all_sub_nodes(i, typ, brute_force))
        return result

    @staticmethod
    def find_parent_of_type(node: uni.UniNode, typ: Type[T]) -> Optional[T]:
        """Check if node has parent of type."""
        while node.parent:
            if isinstance(node.parent, typ):
                return node.parent
            node = node.parent
        return None

    @staticmethod
    def has_parent_of_node(node: uni.UniNode, parent: uni.UniNode) -> bool:
        """Check if node has parent of type."""
        while node.parent:
            if node.parent == parent:
                return True
            node = node.parent
        return False

    def recalculate_parents(self, node: uni.UniNode) -> None:
        """Recalculate parents."""
        if not node:
            return
        for i in node.kid:
            if i:
                i.parent = node
                self.recalculate_parents(i)

    # Transform Implementations
    # -------------------------
    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Run pass."""
        # Only performs passes on proper ASTs
        self.ir_out = ir_in  # TODO: this should go away and just be orig
        if not isinstance(ir_in, uni.UniNode):
            return ir_in
        self.before_pass()
        if not isinstance(ir_in, uni.UniNode):
            raise ValueError("Current node is not an UniNode.")
        self.traverse(ir_in)
        self.after_pass()
        return self.ir_in

    def traverse(self, node: uni.UniNode) -> uni.UniNode:
        """Traverse tree."""
        if self.term_signal:
            return node
        self.cur_node = node
        self.enter_node(node)
        if not self.prune_signal:
            for i in node.kid:
                if i:
                    self.traverse(i)
        else:
            self.prune_signal = False
        self.cur_node = node
        if self.term_signal:
            return node
        self.exit_node(node)
        return node


class PrinterPass(UniPass):
    """Printer Pass for Jac AST."""

    def enter_node(self, node: uni.UniNode) -> None:
        """Run on entering node."""
        self.log_info(f"Entering: {node.__class__.__name__}: {node.loc}")
        super().enter_node(node)

    def exit_node(self, node: uni.UniNode) -> None:
        """Run on exiting node."""
        super().exit_node(node)
        self.log_info(f"Exiting: {node.__class__.__name__}: {node.loc}")
