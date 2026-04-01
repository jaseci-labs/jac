"""Production test: UnknownType must not silently accept any assignment.

When an expression resolves to UnknownType, assigning it to a typed
variable should either error or warn — it should NOT silently pass.
A production type checker must treat Unknown as a signal that type
inference failed, not as a universal "any" type.

Unknown source: magic method resolution on Any-typed values fails,
producing genuine Unknown (e.g. Any + 1 -> Unknown).

Expected errors: 5
  1. bad1: int = unknown_val     — Unknown should not assign to int silently
  2. bad2: str = unknown_val     — Unknown should not assign to str silently
  3. bad3: list[int] = unknown_val  — Unknown should not assign to list silently
  4. bad4: bool = unknown_val    — Unknown should not assign to bool silently
  5. bad5: float = unknown_val   — Unknown should not assign to float silently
"""

with entry {
    # Any + int -> Unknown (magic method __add__ unresolved on Any)
    items: list = [1, 2, 3];
    any_val = items.pop();
    unknown_val = any_val + 1;

    # A production checker should flag these assignments rather than
    # silently accepting them.
    bad1: int = unknown_val;        # Should warn/error: Unknown -> int
    bad2: str = unknown_val;        # Should warn/error: Unknown -> str
    bad3: list[int] = unknown_val;  # Should warn/error: Unknown -> list
    bad4: bool = unknown_val;       # Should warn/error: Unknown -> bool
    bad5: float = unknown_val;      # Should warn/error: Unknown -> float
}
