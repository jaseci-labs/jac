"""Chained comparison semantics (issue #7320 Cluster 2, item 2a).

CPython evaluates `a < b < c` as `(a < b) and (b < c)` with b evaluated
once. Before the fix na lowered only the first link, so `2 < 3 < 1` was
silently True.
"""

glob _BUMPS: int = 0;

def bump(v: int) -> int {
    global _BUMPS;
    _BUMPS += 1;
    return v;
}

def:pub chain_cases -> int {
    a = 1 if 2 < 3 < 1 else 0;
    b = 1 if 1 < 2 < 3 else 0;
    c = 1 if 1 <= 1 <= 1 else 0;
    d = 1 if 3 > 2 > 1 else 0;
    e = 1 if 3 > 2 > 2 else 0;
    f = 1 if 1 < 2 > 0 else 0;
    g = 1 if "a" < "b" < "c" else 0;
    return a * 1000000 + b * 100000 + c * 10000 + d * 1000 + e * 100 + f * 10 + g;
}

def:pub middle_evaluated_once -> int {
    global _BUMPS;
    _BUMPS = 0;
    ok = 1 if 1 < bump(5) < 9 else 0;
    return ok * 10 + _BUMPS;
}

def:pub long_chain -> int {
    w = 1;
    x = 2;
    y = 3;
    z = 2;
    return 1 if w < x < y > z else 0;
}

with entry {
    bump(0);
}
