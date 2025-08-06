"""Expression type evaluation engine."""

from __future__ import annotations

from typing import Optional

import jac.jaclang.compiler.unitree as uni

from .type_factory import TypeFactory
from .types import Type


class TypeEvaluator:
    """Very small subset of an expression evaluator.

    The real implementation will perform comprehensive type inference and
    flow-sensitive analysis.  For now we map a few literal nodes to builtin
    archetype types and fall back to ``Any`` for everything else.
    """

    def __init__(self, factory: Optional[TypeFactory] = None) -> None:
        """Create an evaluator using *factory* for type instances."""
        self.factory = factory or TypeFactory()

    # ------------------------------------------------------------------
    def evaluate(self, node: uni.UniNode) -> Type:
        """Return the :class:`Type` for *node*."""
        if isinstance(node, uni.Int):
            return self.factory.archetype("int")
        if isinstance(node, uni.Float):
            return self.factory.archetype("float")
        if isinstance(node, uni.String):
            return self.factory.archetype("str")
        if isinstance(node, uni.Bool):
            return self.factory.archetype("bool")
        return self.factory.any()
