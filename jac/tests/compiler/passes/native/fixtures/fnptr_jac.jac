"""Jac-to-Jac callable passing via Callable[[...], ret] type annotations.

Tests that:
  1. Callable[[param_types], ret] resolves to the uniform native closure
     value: an RC {fn, env} pair (a plain `def` wraps with a null env).
  2. A Jac `def` can be passed as a Callable argument (ir.Function → closure
     wrap coercion) and called indirectly with the env as a trailing arg.
  3. Indirect calls via a Callable parameter or local produce the correct
     result. The native wrapper entries exist because the closure-pair ABI
     is not callable with raw C function addresses from ctypes.
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

def apply2_add(x: int, y: int) -> int {
    return apply2(add, x, y);
}

def apply2_mul(x: int, y: int) -> int {
    return apply2(mul, x, y);
}

def apply1_negate(x: int) -> int {
    return apply1(negate, x);
}

def call_via_local_add(a: int, b: int) -> int {
    return call_via_local(add, a, b);
}

def call_via_local_mul(a: int, b: int) -> int {
    return call_via_local(mul, a, b);
}
