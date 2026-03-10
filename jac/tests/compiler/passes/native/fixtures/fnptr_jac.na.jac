"""Jac-to-Jac function pointer passing via Callable[[...], ret] type annotations.

Tests that:
  1. Callable[[param_types], ret] resolves to the correct LLVM function pointer type.
  2. A Jac `def` can be passed as a Callable argument (ir.Function → fn-ptr coercion).
  3. Indirect calls via a function-pointer parameter produce the correct result.
"""

def add(a: int, b: int) -> int {
    return a + b;
}

def mul(a: int, b: int) -> int {
    return a * b;
}

def negate(x: int) -> int {
    return -x;
}

"""Apply a binary (int, int)->int function to two arguments."""
def apply2(fn: Callable[[int, int], int], x: int, y: int) -> int {
    return fn(x, y);
}

"""Apply a unary (int)->int function to one argument."""
def apply1(fn: Callable[[int], int], x: int) -> int {
    return fn(x);
}

"""Store a function pointer in a local variable and call through it."""
def call_via_local(fn: Callable[[int, int], int], a: int, b: int) -> int {
    stored: Callable[[int, int], int] = fn;
    return stored(a, b);
}
