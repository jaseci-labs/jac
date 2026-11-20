"""Chained comparisons with membership and identity links (#7593 item 2).

CPython evaluates `a < b in xs` as `(a < b) and (b in xs)` with b
evaluated once; `t is u is w` as `(t is u) and (u is w)`. Before the fix
na statically rejected any chain containing in/not in/is/is not.
"""

glob _BUMPS: int = 0;

def bump(v: int) -> int {
    _BUMPS += 1;
    return v;
}

obj Box {
    has v: int = 0;
}

def:pub chain_in_cases -> int {
    a = 1 if 1 < 2 in [2, 5] else 0;
    b = 1 if 1 < 2 in [3, 5] else 0;
    c = 1 if 3 > 2 not in [9, 8] else 0;
    d = 1 if "a" < "b" in ["b", "c"] else 0;
    e = 1 if "a" < ("be" + "ta") in ["beta", "x"] else 0;
    return a * 10000 + b * 1000 + c * 100 + d * 10 + e;
}

def:pub chain_is_cases -> int {
    t = Box();
    u = t;
    w = Box();
    a = 1 if t is u is u else 0;
    b = 1 if t is u is w else 0;
    c = 1 if w is not t is not u else 0;
    d = 1 if 0 < 1 < 2 else 0;
    return a * 1000 + b * 100 + c * 10 + d;
}

def:pub chain_middle_once -> int {
    _BUMPS = 0;
    ok = 1 if 1 < bump(2) in [2, 9] else 0;
    return ok * 10 + _BUMPS;
}

with entry {
    bump(0);
}
