"""AST pass that annotates nodes with inferred types."""

from __future__ import annotations

import jac.jaclang.compiler.unitree as uni
from jac.jaclang.compiler.passes import UniPass

from ...type_system.type_evaluator import TypeEvaluator
from ...type_system.type_factory import TypeFactory


class TypeCheckPass(UniPass):
    """Lightweight type checking pass.

    The pass currently performs a post-order traversal and attaches a
    ``inferred_type`` attribute to each AST node using
    :class:`TypeEvaluator`.  The design mirrors the structure of Pyright's
    ``TypeEvaluator`` but only covers a minimal subset of Jac at the moment.
    """

    def before_pass(self) -> None:  # pragma: no cover - thin wrapper
        """Initialize evaluator before traversal."""
        factory = TypeFactory()
        self.evaluator = TypeEvaluator(factory)

    def exit_node(self, node: uni.UniNode) -> None:
        """Annotate each node with an inferred type."""
        node.inferred_type = self.evaluator.evaluate(node)  # type: ignore[attr-defined]
        super().exit_node(node)
