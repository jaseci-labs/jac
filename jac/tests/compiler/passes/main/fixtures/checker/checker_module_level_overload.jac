"""Tests for module-level function overload resolution and protocol checking.

This tests two features:
1. Module-level overload resolution: Functions like math.floor have multiple
   @overload signatures. The type checker must collect all overloads.

2. Protocol checking: Functions like math.trunc use protocol types (e.g.,
   _SupportsTrunc). The type checker must verify that float implements
   the required __trunc__ method.

math.floor has two overloads:
  1. floor(x: _SupportsFloor[_T], /) -> _T
  2. floor(x: _SupportsFloatOrIndex, /) -> int

float satisfies both _SupportsFloor (has __floor__) and _SupportsFloatOrIndex
(via SupportsFloat), so math.floor(3.7) should work.

math.trunc has one signature:
  trunc(x: _SupportsTrunc[_T], /) -> _T

float satisfies _SupportsTrunc (has __trunc__), so math.trunc(4.9) should work.
"""
import math;

with entry {
    # These should all pass - float satisfies the protocol requirements
    floor_result: int = math.floor(3.7);
    ceil_result: int = math.ceil(2.3);
    trunc_result: int = math.trunc(4.9);

    # int also works with these functions
    floor_int: int = math.floor(5);
    ceil_int: int = math.ceil(10);
    trunc_int: int = math.trunc(7);

    # Other math functions that take _SupportsFloatOrIndex
    sin_result: float = math.sin(1.0);
    cos_result: float = math.cos(0.5);
    sqrt_result: float = math.sqrt(4.0);

    # Error case: assigning float result to int (math.sin returns float)
    sin_wrong: int = math.sin(1.0);  # Error: Cannot assign float to int
}
