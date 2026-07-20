"""Nested functions capturing enclosing locals.

Read-only captures are forwarded by value at each call (late binding: the
callee sees the variable's value at call time, which for single-threaded
reads is observationally identical to Python's use-time reads). Captures the
nested function rebinds (Jac's implicit-rebind semantics, the sv backend
emits `nonlocal` for these) are forwarded as a pointer to the enclosing
frame's slot, so writes land in the enclosing frame.
"""

def scaled(y: int, v: int) -> int {
    def inner(x: int) -> int {
        return x * y;
    }
    return inner(v);
}

def late_bound(a: int, b: int) -> int {
    y = a;
    def inner(x: int) -> int {
        return x + y;
    }
    r1 = inner(10);
    y = b;
    r2 = inner(10);
    return r1 * 1000 + r2;
}

def rebind_out(n: int) -> int {
    total = 0;
    def bump(k: int) -> int {
        total = total + k;
        return total;
    }
    bump(n);
    bump(n);
    return total;
}

def str_capture(s: str) -> int {
    def measure -> int {
        return len(s);
    }
    return measure() + measure();
}

def lam_parity(y: int) -> int {
    f = lambda (x: int) { x * y; };
    return f(3);
}

def recursive_capture(n: int) -> int {
    depth = 0;
    def walk(k: int) -> int {
        depth = depth + 1;
        if k <= 0 {
            return depth;
        }
        return walk(k - 1);
    }
    return walk(n);
}
