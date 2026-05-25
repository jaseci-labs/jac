"""Native fixture exercising flow/wait.

Native has no threading runtime, so concurrency runs sequentially:
`flow e` evaluates `e` eagerly and yields its value as the handle, and
`wait h` reads that already-computed value. Results match a concurrent
run for independent tasks; there is no actual parallelism.
"""

def task(x: int) -> int {
    return x * 2;
}

# `wait` yields Unknown to the type checker today, so the results are
# cast to pin their static type (a type-system gap, not a native one).
def run_one(n: int) -> int {
    h = flow task(n);
    return (wait h) as int;
}

def run_inline(n: int) -> int {
    return (wait (flow task(n))) as int;
}

def run_two(a: int, b: int) -> int {
    h1 = flow task(a);
    h2 = flow task(b);
    return ((wait h1) as int) + ((wait h2) as int);
}
