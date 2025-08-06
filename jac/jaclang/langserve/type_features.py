"""Type-aware language server features (placeholder)."""

from __future__ import annotations

from typing import List, Tuple

from jac.jaclang.compiler.type_system import TypeEvaluator, TypeFactory

_factory = TypeFactory()
_evaluator = TypeEvaluator(_factory)


def get_completions(source: str, position: Tuple[int, int]) -> List[str]:
    """Return completion items at *position*.

    This placeholder simply returns an empty list but establishes the API for
    future type-aware completions.
    """
    return []


def get_hover(source: str, position: Tuple[int, int]) -> str:
    """Return hover information for symbol at *position*.

    For now we return a generic ``Any`` type string to demonstrate the flow from
    the language server to the type evaluation engine.
    """
    return str(_factory.any())


def get_diagnostics(source: str) -> List[str]:
    """Return diagnostics for *source*.

    Diagnostics require a full type checker; this placeholder simply returns an
    empty list to keep the LSP pipeline exercised.
    """
    return []
