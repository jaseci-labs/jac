# Lambda expressions in native codespace.
# Phase 1: Simple lambdas (no captures) — function pointers.

# Lambda assigned to a variable and called
def apply_int_op(a: int, b: int) -> int {
    op = lambda (x: int, y: int) -> int { return x + y; };
    return op(a, b);
}

# Lambda with no parameters
def get_forty_two -> int {
    f = lambda -> int { return 42; };
    return f();
}

# Lambda with single parameter
def negate_via_lambda(x: int) -> int {
    neg = lambda (n: int) -> int { return 0 - n; };
    return neg(x);
}
