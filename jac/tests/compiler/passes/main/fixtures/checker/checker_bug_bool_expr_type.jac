"""Bug #11: BoolExpr (and/or) always returns the last operand's type.

Python semantics: `x and y` returns x if x is falsy, y otherwise.
The type should be type(x) | type(y), not just type(y).

Similarly, `x or y` returns x if x is truthy, y otherwise.
The type should be type(x) | type(y).

The current implementation returns operand_types[-1] which is always
the last operand's type, losing the first operand's type info.
"""

def get_str -> str {
    return "hello";
}

def get_int -> int {
    return 42;
}

with entry {
    # 'x and y' where x: str, y: int => should be str | int
    # Bug: type checker says this is int (last operand only)
    result_and = get_str() and get_int();

    # With correct typing (str|int), this should ERROR because str|int
    # is not assignable to int (the str part can't go into int).
    # With the bug, result_and is int, so this PASSES incorrectly.
    check_and_int: int = result_and;  # <-- Should be Error (str|int -> int)

    # 'x or y' where x: str, y: int => should be str | int
    # Bug: type checker says this is int (last operand only)
    result_or = get_str() or get_int();

    # Same issue: should ERROR because str|int -> int is not valid
    # With bug, result_or is int, so this passes incorrectly.
    check_or_int: int = result_or;  # <-- Should be Error (str|int -> int)
}
