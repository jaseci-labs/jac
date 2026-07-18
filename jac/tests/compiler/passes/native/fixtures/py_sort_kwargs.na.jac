"""sort()/sorted() keyword arguments (issue #7320 Cluster 2, item 2d).

Before the fix `reverse=` and `key=` were silently dropped: the list was
bubble-sorted ascending by raw element regardless, so ranking code that
compiled clean returned wrong orderings.
"""

def:pub sort_reverse -> int {
    a = [3, 1, 2];
    a.sort(reverse=True);
    return a[0] * 100 + a[1] * 10 + a[2];
}

def:pub sorted_reverse_copies -> int {
    b = [3, 1, 2];
    c = sorted(b, reverse=True);
    return b[0] * 1000 + c[0] * 100 + c[1] * 10 + c[2];
}

def:pub sort_key_len -> int {
    d = ["dd", "ccc", "a"];
    d.sort(key=lambda (s: str) -> int { return len(s); });
    ok1 = 1 if d[0] == "a" else 0;
    ok2 = 1 if d[1] == "dd" else 0;
    ok3 = 1 if d[2] == "ccc" else 0;
    return ok1 * 100 + ok2 * 10 + ok3;
}

def:pub sort_key_and_reverse -> int {
    e = [5, 12, 3];
    e.sort(key=lambda (x: int) -> int { return x % 10; }, reverse=True);
    return e[0] * 10000 + e[1] * 100 + e[2];
}

with entry {
    sort_reverse();
}
