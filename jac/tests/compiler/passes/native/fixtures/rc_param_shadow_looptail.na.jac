"""Loop-exit cleanup must release loop-body locals even when their names
match some other function's params (issue #7466 bug 2). `use2`'s borrow
params are named `a` and `b`, the same names `churn` uses for its two fresh
per-iteration locals. If per-function param state leaks across functions,
the loop-exit (iter_end) and scope-exit cleanups skip `a`/`b` as
"borrowed params", so the final iteration's two Boxes are never freed."""

obj Box {
    has n: int = 0;
}

def mk(i: int) -> Box {
    b: own Box = Box(n=i);
    return b;
}

def use2(a: &Box, b: &Box) -> int {
    return a.n + b.n;
}

def churn(rounds: int) -> int {
    acc = 0;
    for i in range(rounds) {
        a = mk(i);
        b = mk(i + 1);
        acc += use2(&a, &b);
    }
    return acc;
}
