"""Core type system for Jac language.

This package provides a minimal, Pyright-inspired type framework used by
the Jac compiler and language server.  The implementation focuses on a
simple object-based hierarchy with caching hooks that can be extended as the
type checker matures.
"""

from .flow_analyzer import FlowAnalyzer
from .type_cache import TypeCache
from .type_evaluator import TypeEvaluator
from .type_factory import TypeFactory
from .types import AbilityType, AnyType, ArchetypeType, NoneType, Type, WalkerType

__all__ = [
    "Type",
    "AnyType",
    "NoneType",
    "ArchetypeType",
    "AbilityType",
    "WalkerType",
    "TypeFactory",
    "TypeCache",
    "TypeEvaluator",
    "FlowAnalyzer",
]
