"""Tests for module-level function overload resolution.

Module-level functions like math.floor have multiple @overload signatures.
The type checker must collect all overloads and try each one when checking
argument compatibility.

math.floor has two overloads:
  1. floor(x: _SupportsFloor[_T], /) -> _T
  2. floor(x: _SupportsFloatOrIndex, /) -> int

When called with int, the second overload matches and returns int.
"""
import math;

with entry {
    # int works with floor/ceil - uses _SupportsFloatOrIndex overload
    floor_int: int = math.floor(5);
    ceil_int: int = math.ceil(10);

    # Other math functions return float
    sin_result: float = math.sin(1.0);
    cos_result: float = math.cos(0.5);
    sqrt_result: float = math.sqrt(4.0);

    # Error case: assigning float result to int (math.sin returns float)
    sin_wrong: int = math.sin(1.0);  # Error: Cannot assign float to int
}
