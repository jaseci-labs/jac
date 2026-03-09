"""Bug #1: 'is', 'is not', 'in', 'not in' operators return UnknownType.

The operations.jac file computes _convert_to_instance(bool_class) but
doesn't return the result, so the expression falls through and returns
UnknownType instead of bool.

Expected: 'is' and 'in' expressions infer as bool, so assigning to str
should produce a type error.
"""

obj Foo {}

with entry {
    a = Foo();
    b = Foo();

    # 'is' should produce bool
    r1: bool = a is b;  # <-- Should be Ok (bool -> bool)
    r2: str = a is b;  # <-- Should be Error (bool not assignable to str)

    # 'is not' should produce bool
    r3: bool = a is not b;  # <-- Should be Ok
    r4: str = a is not b;  # <-- Should be Error

    # 'in' should produce bool
    items: list = [1, 2, 3];
    r5: bool = 1 in items;  # <-- Should be Ok
    r6: str = 1 in items;  # <-- Should be Error

    # 'not in' should produce bool
    r7: bool = 1 not in items;  # <-- Should be Ok
    r8: str = 1 not in items;  # <-- Should be Error
}
