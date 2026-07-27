"""Subscript augmented assignment semantics (silent-wrong-value family).

CPython computes `seq[i] op= rhs` as `seq[i] = seq[i] op rhs`. Before the
fix na dropped the read-modify step for subscript targets entirely and
stored the raw RHS into the element (`v[0] -= 0.25` left 0.25) - for every
op, on lists and dicts alike. Float `obj.field //= x` took the same silent
RHS-store fallback on the field path, and float floor-div through any aug
path skipped the floor() of the plain `//` operator.
"""

glob _EVALS: int = 0;

obj Holder {
    has f: float = 7.0,
        n: int = 20;
}

def bump_idx(v: int) -> int {
    _EVALS += 1;
    return v;
}

def:pub list_int_ops -> int {
    v = [7];
    v[0] += 3;
    a = v[0];
    v[0] -= 2;
    b = v[0];
    v[0] *= 3;
    c = v[0];
    v[0] //= 5;
    d = v[0];
    v[0] %= 3;
    e = v[0];
    return a * 10000000 + b * 100000 + c * 1000 + d * 10 + e;
}

def:pub list_int_bitops -> int {
    v = [17];
    v[0] <<= 3;
    a = v[0];
    v[0] >>= 1;
    b = v[0];
    v[0] |= 3;
    c = v[0];
    v[0] ^= 5;
    d = v[0];
    v[0] &= 31;
    e = v[0];
    v[0] **= 5;
    f = v[0];
    return ((((a * 1000 + b) * 1000 + c) * 1000 + d) * 1000 + e) * 1000 + f;
}

def:pub list_float_ops -> int {
    v = [8.0];
    v[0] += 1.5;
    a = int(v[0] * 10.0);
    v[0] -= 0.25;
    b = int(v[0] * 100.0);
    v[0] *= 2.0;
    c = int(v[0] * 10.0);
    v[0] //= 4.0;
    d = int(v[0]);
    v[0] /= 5.0;
    e = int(v[0] * 10.0);
    return (((a * 10000 + b) * 10000 + c) * 100 + d) * 100 + e;
}

def:pub dict_ops -> int {
    d: dict[int, int] = {};
    d[3] = 10;
    d[3] += 5;
    a = d[3];
    d[3] -= 7;
    b = d[3];
    d[3] *= 4;
    c = d[3];
    s: dict[str, float] = {};
    s["k"] = 1.5;
    s["k"] *= 4.0;
    e = int(s["k"]);
    return ((a * 100 + b) * 100 + c) * 100 + e;
}

def:pub field_scalar_ops -> int {
    h = Holder();
    h.f //= 2.0;
    a = int(h.f);
    h.f *= 2.5;
    b = int(h.f * 10.0);
    h.n %= 6;
    c = h.n;
    return (a * 1000 + b) * 100 + c;
}

def:pub index_evaluated_once -> int {
    _EVALS = 0;
    m = [10, 20];
    m[bump_idx(1)] += 7;
    return m[1] * 10 + _EVALS;
}

with entry {
    bump_idx(0);
}
