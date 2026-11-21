"""Entry-block assignments are module globals natively (#7626 A1).

Python treats `with entry` assignments as module state: lambdas and
defs read them as globals, late-bound at call time. The native backend
lowers entry-block top-level assignments to module globals (registered
through the same path as `glob`, initialized in jac_entry after
`__jac_glob_init`), so these shapes lower natively with identical
semantics instead of the old frame-local E5092 divergence.
"""

glob acc: list[int] = [];

with entry {
    k = 7;
    fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x + k; }];
    f = fns[0];
    acc.append(f(1));
    k = 100;
    acc.append(f(1));
}

def read_k -> int {
    return k;
}

def acc_len -> int {
    return len(acc);
}

def acc_at(i: int) -> int {
    return acc[i];
}
