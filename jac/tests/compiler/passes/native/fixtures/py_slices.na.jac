"""Slice semantics (issue #7320 Cluster 3).

Negative bounds crashed (raw stop-start fed rc_alloc/memcpy), negative
start silently returned empty, and step was ignored. All forms below
must match CPython: negative indices wrap, bounds clamp, steps walk in
either direction.
"""

def:pub str_slices -> int {
    s = "hello" + "!";
    a = 1 if s[1:-1] == "ello" else 0;
    b = 1 if s[:-2] == "hell" else 0;
    c = 1 if s[-3:] == "lo!" else 0;
    d = 1 if s[0:999] == "hello!" else 0;
    e = 1 if s[::-1] == "!olleh" else 0;
    f = 1 if s[::2] == "hlo" else 0;
    g = 1 if s[4:1] == "" else 0;
    h = 1 if s[-100:2] == "he" else 0;
    return a * 10000000 + b * 1000000 + c * 100000 + d * 10000 + e * 1000 + f * 100 + g * 10 + h;
}

def sum_list(xs: list[int]) -> int {
    acc = 0;
    for x in xs {
        acc = acc * 10 + x;
    }
    return acc;
}

def:pub list_slices -> int {
    xs = [1, 2, 3, 4, 5];
    a = 1 if sum_list(xs[1:-1]) == 234 else 0;
    b = 1 if sum_list(xs[::-1]) == 54321 else 0;
    c = 1 if sum_list(xs[0:999]) == 12345 else 0;
    d = 1 if sum_list(xs[-2:]) == 45 else 0;
    e = 1 if len(xs[4:1]) == 0 else 0;
    f = 1 if sum_list(xs[::2]) == 135 else 0;
    return a * 100000 + b * 10000 + c * 1000 + d * 100 + e * 10 + f;
}

def:pub slice_zero_step_raises -> int {
    xs = [1, 2, 3];
    try {
        ys = xs[::0];
        return len(ys);
    } except Exception {
        return 1;
    }
}

with entry {
    str_slices();
}
