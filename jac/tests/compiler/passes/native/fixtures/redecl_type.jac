"""Regression fixture for variable re-declaration type mismatch in assignment codegen.

When the same variable name is re-declared with a different type (x: T = ...)
the codegen must allocate a fresh alloca of the new type rather than storing
through the wrongly-typed pointer from the original declaration.

Before the fix, e.g. declaring x: int first and then x: bool would store an
i1 into an i64 alloca, causing IR type mismatches or wrong values at runtime.
"""

"""Re-declares an int variable as bool; returns 1 if True else 0."""
def:pub redecl_int_to_bool_true() -> int {
    x: int = 0;
    x: bool = True;
    if x {
        return 1;
    }
    return 0;
}

"""Re-declares an int variable as bool = False; should return 0."""
def:pub redecl_int_to_bool_false() -> int {
    x: int = 99;
    x: bool = False;
    if x {
        return 1;
    }
    return 0;
}

"""Re-declares a variable with the same type; should just update the value."""
def:pub redecl_same_type_int() -> int {
    x: int = 50;
    x: int = 99;
    return x;
}

"""Re-declares a bool variable as int; should return the int value."""
def:pub redecl_bool_to_int() -> int {
    x: bool = True;
    x: int = 42;
    return x;
}
