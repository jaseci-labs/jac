"""Multi-statement lambda used as a default parameter value.

Default values are evaluated at definition time in the enclosing scope, so a
multi-statement lambda default (lowered by the Python target to a hoisted
``FunctionDef`` plus a ``Name`` reference) must have its hoist emitted *before*
the function definition. This fixture guards that (regression for a runtime
``NameError: name '__jac_lambda_N' is not defined``).
"""

def shout(
    msg: str,
    fmt: type = lambda (s: str) -> str {
        up = s.upper();
        up + "!"
    }
) -> str {
    return fmt(msg);
}

def transform(
    n: int,
    step: type = lambda (x: int) -> int {
        y = x * 2;
        return y + 1;
    }
) -> int {
    return step(n);
}

# Parity: a single-expression lambda default (fast path, no hoist) in the same
# position must keep working alongside the multi-statement form.
def transform2(n: int, step: type = lambda (x: int) -> int { x * 2 }) -> int {
    return step(n);
}

with entry {
    print(shout("hi"));
    print(transform(5));
    print(transform2(5));
}
