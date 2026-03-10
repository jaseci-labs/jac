"""Bug #12: CompareExpr has no handler — returns UnknownType instead of bool.

Comparison expressions like a < b, a == b, a >= b should all return bool.
Since there is no case for uni.CompareExpr in _get_type_of_expression_core,
they fall through to UnknownType.

Expected: comparison expressions should infer as bool, so assigning to str
should produce a type error.
"""

with entry {
    a = 10;
    b = 20;

    # All of these should be bool
    r1: bool = a < b;  # <-- Should be Ok
    r2: bool = a > b;  # <-- Should be Ok
    r3: bool = a <= b;  # <-- Should be Ok
    r4: bool = a >= b;  # <-- Should be Ok
    r5: bool = a == b;  # <-- Should be Ok
    r6: bool = a != b;  # <-- Should be Ok

    # Assigning comparison to str should Error
    s1: str = a < b;  # <-- Should be Error (bool not assignable to str)
    s2: str = a == b;  # <-- Should be Error
}
