"""Fixture: a loop whose narrowed type never stabilizes must terminate and stay
sound (it must not hang, crash, or raise a spurious error).

`x = [x]` grows the type every iteration (x, list[x], list[list[x]], ...), so the
fixed point never converges. After the pass cap the resolver falls back to the
declared type (`object` here) - the widest, always-sound result - rather than a
half-converged guess. This pins that behavior: the type-growing loop below must
type-check cleanly. If a future change instead returned the non-converged guess,
or looped without a cap, this fixture would catch it (spurious error or hang).
"""

def grow(items: list[int]) -> int {
    x: object = 0;
    for _i in items {
        x = [x];
    }
    return len(items);
}

def grow_nested(rows: list[int], cols: list[int]) -> int {
    y: object = 0;
    for _r in rows {
        for _c in cols {
            y = [y, y];
        }
    }
    return len(rows);
}
