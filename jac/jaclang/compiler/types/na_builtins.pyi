# ruff: noqa: N801, N802, N803
"""Native-only builtins.

These names belong to the one builtin namespace of the language, but only
the native backend can realize them. The type checker resolves them in every
module; using one records a native requirement on the enclosing unit, which
the placement step honors or reports. Nothing here shadows a Python builtin:
`open`, `iter` and `next` are typed by the Python stubs in every codespace,
and the native runtime's file and iterator types are bound to those
interfaces by the native binding table.
"""

from __future__ import annotations

from typing import TypeVar, overload

__all__ = [
    "managed",
    "take",
    "swap",
    "Region",
    "region_of",
]

_T = TypeVar("_T")

def managed(__x: _T) -> _T: ...

def take(__place: _T) -> _T: ...

def swap(__a: _T, __b: _T) -> None: ...

# First-class region handle: an ownable, sendable, escape-checked allocation
# extent opened by `in <handle> { ... }`. Native codegen lowers it to an arena.
class Region:
    @overload
    def partition(self) -> Region: ...
    @overload
    def partition(self, n: int) -> tuple[Region, ...]: ...

# The region a value was allocated in (the growth anchor of a traversal),
# or None for a managed value.
def region_of(__x: object) -> Region | None: ...
