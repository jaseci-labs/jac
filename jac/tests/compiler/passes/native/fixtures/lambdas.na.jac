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


# --- Phase 2: Capturing closures ---

# Lambda captures a local variable from enclosing scope
def add_offset(x: int, offset: int) -> int {
    adder = lambda (n: int) -> int { return n + offset; };
    return adder(x);
}

# Lambda captures multiple variables
def weighted_sum(a: int, b: int, wa: int, wb: int) -> int {
    compute = lambda -> int { return a * wa + b * wb; };
    return compute();
}

# Closure used as a factory-like pattern: outer sets multiplier, inner uses it
def make_scaler(x: int, factor: int) -> int {
    scale = lambda (n: int) -> int { return n * factor; };
    return scale(x);
}
