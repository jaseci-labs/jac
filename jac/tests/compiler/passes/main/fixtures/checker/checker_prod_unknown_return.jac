"""Production test: Functions returning Unknown must be flagged.

When a function has a return type annotation but returns an expression
that resolves to UnknownType, the checker should detect the mismatch
or warn about lost type information.

Unknown source: magic method resolution on Any-typed values fails,
producing genuine Unknown (e.g. Any + 1 -> Unknown).

Expected errors: 3
  1. returns_int_but_unknown  — Unknown returned where int expected
  2. returns_str_but_unknown  — Unknown returned where str expected
  3. caller bad assignment    — downstream int->str mismatch
"""

def returns_int_but_unknown() -> int {
    items: list = [1, 2, 3];
    any_val = items.pop();
    val = any_val + 1;
    return val;                    # Error: Unknown returned where int declared
}

def returns_str_but_unknown() -> str {
    items: list = ["a", "b"];
    any_val = items.pop();
    val = any_val + "x";
    return val;                    # Error: Unknown returned where str declared
}

with entry {
    # Even if the above functions are declared -> int and -> str,
    # the return paths are suspect. Downstream uses should be correct
    # per the declared type, but the function body has a type hole.
    r1: int = returns_int_but_unknown();   # Ok per declaration
    bad1: str = returns_int_but_unknown(); # Error: int -> str
}
