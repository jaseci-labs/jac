"""`or`/`and` as value expressions (issue #7320 Cluster 2, item 2b).

CPython returns the deciding operand itself: `a or b` is a if truthy
else b, `a and b` is b if a truthy else a. Before the fix na collapsed
the expression to an i1 truth bit, so int operands came back 0/1 and a
returned `s or "fallback"` was a garbage pointer (segfault).
"""

glob _CALLS: int = 0;

def bump -> int {
    global _CALLS;
    _CALLS += 1;
    return 99;
}

def:pub bool_ops_int -> int {
    v = 5 or 7;
    w = 0 or 7;
    x = 3 and 9;
    y = 0 and 9;
    return v * 1000 + w * 100 + x * 10 + y;
}

def pick(s: str) -> str {
    return s or "dflt";
}

def:pub bool_ops_str -> int {
    s = "";
    r = s or "fallback";
    t = "real" or "unused";
    a = pick("");
    b = pick("xyz");
    r_ok = 1 if r == "fallback" else 0;
    t_ok = 1 if t == "real" else 0;
    a_ok = 1 if a == "dflt" else 0;
    b_ok = 1 if b == "xyz" else 0;
    return r_ok * 1000 + t_ok * 100 + a_ok * 10 + b_ok;
}

def:pub bool_ops_short_circuit -> int {
    global _CALLS;
    _CALLS = 0;
    v = 5 or bump();
    w = 0 and bump();
    return v * 100 + w * 10 + _CALLS;
}

with entry {
    bump();
}
