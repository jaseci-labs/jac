"""Multi-statement lambda passed as a decorator argument.

`replace_with` is a decorator factory: it receives a lambda `g` and returns a
decorator that substitutes `g` for the wrapped function. The lambdas handed to
`@replace_with(...)` have multi-statement bodies, which the Python target lowers
via a hoisted ``FunctionDef`` plus a ``Name`` reference. This fixture guards that
the hoist is emitted into the enclosing scope *before* the decorated definition
(regression for a runtime ``NameError: name '__jac_lambda_N' is not defined``).
"""

def replace_with(g: type) -> type {
    return lambda (fn: type) -> type { g };
}

# Implicit (Rust-style) tail return in the multi-statement body.
@replace_with(
    lambda (x: int) -> int {
        a = x + 1;
        a * 2
    }
)
def slot(x: int) -> int {
    return x;
}

# Explicit `return` in the multi-statement body.
@replace_with(
    lambda (x: int) -> int {
        b = x * 3;
        return b - 1;
    }
)
def slot2(x: int) -> int {
    return x;
}

# Parity: a single-expression lambda (fast path, no hoist) in the same position
# must keep working alongside the multi-statement form.
@replace_with(lambda (x: int) -> int { x + 100 })
def slot3(x: int) -> int {
    return x;
}

with entry {
    print(slot(10));
    print(slot2(10));
    print(slot3(10));
}
