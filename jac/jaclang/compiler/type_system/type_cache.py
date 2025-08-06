"""Simple cache for type instances."""

from __future__ import annotations

from typing import Callable, Dict, Generic, Hashable, Tuple, TypeVar


T = TypeVar("T")


class TypeCache(Generic[T]):
    """Cache used by :class:`TypeFactory` to intern type instances."""

    def __init__(self) -> None:
        """Create an empty cache."""
        self._cache: Dict[Tuple[Hashable, ...], T] = {}

    def get(self, key: Tuple[Hashable, ...], creator: Callable[[], T]) -> T:
        """Retrieve a cached value, creating it if necessary."""
        if key not in self._cache:
            self._cache[key] = creator()
        return self._cache[key]
