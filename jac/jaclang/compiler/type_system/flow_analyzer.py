"""Control-flow analysis for type narrowing (placeholder)."""

from __future__ import annotations

import jac.jaclang.compiler.unitree as uni

from .type_evaluator import TypeEvaluator


class FlowAnalyzer:
    """Performs extremely small-scale flow analysis.

    At the moment this class simply walks the AST and asks the provided
    :class:`TypeEvaluator` for the type of each node.  In the future it will
    handle control-flow graphs and type narrowing similar to Pyright's
    implementation.
    """

    def __init__(self, evaluator: TypeEvaluator) -> None:
        """Store the evaluator used for type inference."""
        self.evaluator = evaluator

    def analyze(self, node: uni.UniNode) -> None:
        """Traverse *node* to prime type inference caches."""
        for child in node.kid:
            if child:
                self.evaluator.evaluate(child)
                self.analyze(child)
