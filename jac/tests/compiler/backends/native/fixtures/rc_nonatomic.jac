"""RC-churn fixture for the JAC_RC_NONATOMIC compile-time flag.

Every iteration allocates, retains, and releases RC objects (strings and
a list), so refcount updates dominate; the result is a deterministic
checksum that any dropped or doubled retain/release corrupts (premature
free crashes, a leak is invisible here but the IR-shape test pins the
emission instead).
"""

def rc_churn(n: int) -> int {
    acc: int = 0;
    l: list[str] = [];
    i: int = 0;
    while i < n {
        s: str = "x" + str(i);
        l.append(s);
        acc = acc + len(s);
        i = i + 1;
    }
    i = 0;
    while i < n {
        acc = acc + len(l[i]);
        i = i + 1;
    }
    return acc;
}
