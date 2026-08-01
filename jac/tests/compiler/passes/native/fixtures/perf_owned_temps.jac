"""P-06: Owned-temporary release across value-consumption seams (#6464).

Each loop iteration produces several heap temporaries that are consumed by a
`for`-loop, a comprehension, an `in` test, `set.add`, and a function-call
argument. The native RC code-gen must release each consumed temporary; if any
seam forgets, the temporary leaks and peak RSS grows without bound even with GC
enabled (the bug fixed in #6464). With GC on every temporary is reclaimed and
RSS stays flat, so this fixture's GC-vs-no-GC delta guards against a regression
of those releases.

Timing and RSS are measured externally by the gc test via /usr/bin/time.
"""

def gen(n: int) -> list[int] {
    out: list[int] = [];
    i = 0;
    while i < n {
        out.append(i);
        i = i + 1;
    }
    return out;
}

def take(xs: list[int]) -> int {
    return len(xs);
}

def attacks(n: int) -> set[tuple[int, int]] {
    s: set[tuple[int, int]] = set();
    i = 0;
    while i < n {
        s.add((i, i));
        i = i + 1;
    }
    return s;
}

with entry {
    total: int = 0;
    k: int = 0;
    while k < 100000 {
        # 1. for-loop over a call-returned temporary list
        for v in gen(16) {
            total = total + v;
        }
        # 2. set comprehension over a call-returned temporary list
        sq: set[int] = {v for v in gen(16)};
        total = total + len(sq);
        # 3. membership test against a call-returned temporary set (+ tuple key);
        #    attacks() also exercises set.add of value tuples
        if (3, 3) in attacks(16) {
            total = total + 1;
        }
        # 4. owned-temporary (list literal + call result) passed as a call argument
        total = total + take(gen(16));
        total = total + take([0, 1, 2, 3, 4, 5, 6, 7]);
        k = k + 1;
    }
    print("OK owned_temps total =", total);
}
