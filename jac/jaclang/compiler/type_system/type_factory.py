"""Factory that creates and caches common Jac types."""

from __future__ import annotations

from typing import Optional, cast

from .type_cache import TypeCache
from .types import AnyType, ArchetypeType, NoneType, Type


class TypeFactory:
    """Centralized type construction with caching."""

    def __init__(self) -> None:
        """Create a new :class:`TypeFactory`."""
        self._cache: TypeCache[Type] = TypeCache()

    # Builtin singletons -------------------------------------------------
    def any(self) -> AnyType:
        """Return the shared ``Any`` instance."""
        return cast(AnyType, self._cache.get(("any",), AnyType))

    def none(self) -> NoneType:
        """Return the shared ``None`` instance."""
        return cast(NoneType, self._cache.get(("none",), NoneType))

    # Archetypes ---------------------------------------------------------
    def archetype(
        self, name: str, base: Optional[ArchetypeType] = None
    ) -> ArchetypeType:
        """Create or reuse an :class:`ArchetypeType`."""
        return cast(
            ArchetypeType,
            self._cache.get(("arch", name, base), lambda: ArchetypeType(name, base)),
        )
