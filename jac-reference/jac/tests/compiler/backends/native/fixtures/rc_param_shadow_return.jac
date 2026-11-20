"""Param names of one function must not perturb RC codegen of another
(issue #7466 bug 1). `push` is never called; its params register the names
`s` and `v`. `make_vec` binds a fresh Vec to a local that happens to also be
named `v` and returns it -- if per-function param state leaks across
functions, the return path treats `v` as a borrowed param and emits a
retain-on-return, so every returned Vec leaves the factory at rc=2 and the
caller's single release can never free it."""

obj Stack {
    has vals: list[int] = [];
}

obj Vec {
    has xs: list[float] = [];
}

def push(s: Stack, v: int) {
    s.vals.append(v);
}

def make_vec(n: int) -> Vec {
    v = Vec();
    for i in range(n) {
        v.xs.append(i * 0.5);
    }
    return v;
}

def sum_first(rounds: int) -> int {
    total = 0.0;
    for rd in range(rounds) {
        a = make_vec(4);
        total += a.xs[1];
    }
    return int(total * 2.0);
}
