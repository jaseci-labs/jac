"""A scalar (int) local initialized from a call must not be move-tracked
under --enforce-nogc (issue #7466 bug 5): scalars are copied by value, so
passing `iters` to range() in a for-header (whose CFG node sits on the loop
back edge) must not report use-after-move."""

def pow2(n: int) -> int {
    r = 1;
    for i in range(n) {
        r *= 2;
    }
    return r;
}

def f(m: int) -> int {
    total = 0;
    iters = pow2(m);
    for i in range(iters) {
        total += i;
    }
    return total;
}

with entry {
    print(f(5));
}
