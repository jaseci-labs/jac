"""Bug #13: IfExpr (ternary) has no handler — returns UnknownType.

The expression `x if condition else y` should return the union of
the types of x and y (or a common base type). Since there is no
case for IfExpr, it returns UnknownType.

Expected: ternary expressions should infer the type of their branches.
"""

with entry {
    flag = True;

    # Same types in both branches -> should be that type
    r1 = "yes" if flag else "no";
    check1: str = r1;  # <-- Should be Ok (str if ... else str -> str)

    # Different types in branches -> should be union
    r2 = 42 if flag else "no";
    check2: int = r2;  # <-- Should be Error (int|str not assignable to int)

    # Ternary assigned to explicit type
    r3: str = "yes" if flag else "no";  # <-- Should be Ok
}
