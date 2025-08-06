"""Basic type hierarchy for Jac language.

The classes defined here intentionally provide only the minimum functionality
required for early type checking experiments.  They are designed to mirror
Pyright's object-based representation while remaining lightweight enough to
extend incrementally.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


class Type:
    """Base class for all Jac types."""

    name: str

    def __init__(self, name: str) -> None:
        """Initialize a type with *name*."""
        self.name = name

    def __repr__(self) -> str:  # pragma: no cover - trivial
        """Return ``repr(self)``."""
        return self.name


class AnyType(Type):
    """Represents an unconstrained type."""

    def __init__(self) -> None:
        """Initialize ``Any`` type."""
        super().__init__("Any")


class NoneType(Type):
    """Represents the ``None`` type."""

    def __init__(self) -> None:
        """Initialize ``None`` type."""
        super().__init__("None")


class BuiltinType(Type):
    """Simple built-in type wrapper."""

    pass


class ArchetypeType(Type):
    """Jac archetype (class) type."""

    def __init__(self, name: str, base: Optional["ArchetypeType"] = None) -> None:
        """Create a new archetype type."""
        super().__init__(name)
        self.base = base


class WalkerType(ArchetypeType):
    """Jac walker type."""

    pass


@dataclass
class AbilityType(Type):
    """Ability (method) type with parameter and return annotations."""

    params: List[Type]
    returns: Type

    def __init__(
        self, params: Optional[List[Type]] = None, returns: Optional[Type] = None
    ) -> None:
        """Create an ability type."""
        Type.__init__(self, "Ability")
        self.params = params or []
        self.returns = returns or AnyType()
