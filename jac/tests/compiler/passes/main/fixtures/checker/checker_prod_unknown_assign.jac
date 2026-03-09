"""Production test: UnknownType must not silently accept any assignment.

When an expression resolves to UnknownType, assigning it to a typed
variable should either error or warn — it should NOT silently pass.
A production type checker must treat Unknown as a signal that type
inference failed, not as a universal "any" type.

Unknown sources used here:
  - Bare generic list.pop() returns Unknown (no type param on list)
  - Method on bare dict returns Unknown
  - getattr() returns Unknown

Expected errors: 5
  1. bad1: int = unknown_val     — Unknown should not assign to int silently
  2. bad2: str = unknown_val     — Unknown should not assign to str silently
  3. bad3: list[int] = unknown_val  — Unknown should not assign to list silently
  4. bad4: bool = unknown_val    — Unknown should not assign to bool silently
  5. bad5: float = unknown_val   — Unknown should not assign to float silently
"""

with entry {
    # Bare generic list (no type param) — .pop() returns Unknown
    items: list = [1, 2, 3];
    unknown_val = items.pop();

    # A production checker should flag these assignments rather than
    # silently accepting them. Unknown is assignable to everything
    # because is_any_type() returns True for UnknownType.
    bad1: int = unknown_val;        # Should warn/error: Unknown -> int
    bad2: str = unknown_val;        # Should warn/error: Unknown -> str
    bad3: list[int] = unknown_val;  # Should warn/error: Unknown -> list
    bad4: bool = unknown_val;       # Should warn/error: Unknown -> bool
    bad5: float = unknown_val;      # Should warn/error: Unknown -> float
}
