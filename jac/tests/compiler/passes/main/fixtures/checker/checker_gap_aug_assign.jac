"""Gap #35: Augmented assignment operators are never type-checked.

exit_assignment ignores nd.aug_op. It only checks that the RHS is
assignable to the LHS type, but never validates the augmented operator
is valid for those types (e.g., __iadd__, __isub__, __imul__).

The REAL gap: when assign_type(rhs, lhs) passes but the operator
does not exist for the given types. E.g., list -= list passes
assign_type but list has no __isub__.

Expected errors (operator-specific, NOT caught by assign_type):
  1. list -= list      — list has no __isub__
  2. list /= list      — list has no __itruediv__
  3. dict -= dict      — dict has no __isub__
  4. str /= str        — str has no __itruediv__
  5. str //= str       — str has no __ifloordiv__
  6. set /= set        — set has no __itruediv__
"""

with entry {
    # --- Cases that should ERROR (operator doesn't exist) ---
    # In all these cases, assign_type(rhs_type, lhs_type) PASSES
    # because the types match, but the augmented operator is invalid.

    # Case 1: list -= list (list has no __isub__)
    lst1: list[int] = [1, 2, 3];
    lst1 -= [1, 2];       # Error: list has no __isub__

    # Case 2: list /= list (list has no __itruediv__)
    lst2: list[int] = [1, 2, 3];
    lst2 /= [1];          # Error: list has no __itruediv__

    # Case 3: dict -= dict (dict has no __isub__)
    d1: dict[str, int] = {"a": 1, "b": 2};
    d1 -= {"a": 0};       # Error: dict has no __isub__

    # Case 4: str /= str (str has no __itruediv__)
    s1: str = "hello";
    s1 /= "l";            # Error: str has no __itruediv__

    # Case 5: str //= str (str has no __ifloordiv__)
    s2: str = "hello";
    s2 //= "l";           # Error: str has no __ifloordiv__

    # Case 6: set /= set (set has no __itruediv__)
    st1: set[int] = {1, 2, 3};
    st1 /= {1};           # Error: set has no __itruediv__

    # --- Cases that SHOULD be valid (operator exists) ---

    # Valid: int += int (__iadd__ exists)
    y: int = 10;
    y += 5;               # Ok

    # Valid: str += str (__iadd__ exists)
    s3: str = "hi";
    s3 += " world";       # Ok

    # Valid: list += list (__iadd__/extend exists)
    lst3: list[int] = [1];
    lst3 += [2, 3];       # Ok

    # Valid: float *= int (__imul__ exists)
    f: float = 3.14;
    f *= 2;               # Ok

    # Valid: set |= set (__ior__ exists)
    st2: set[int] = {1, 2};
    st2 |= {3, 4};        # Ok

    # Valid: dict |= dict (__ior__ exists, Python 3.9+)
    d2: dict[str, int] = {"a": 1};
    d2 |= {"b": 2};       # Ok
}
