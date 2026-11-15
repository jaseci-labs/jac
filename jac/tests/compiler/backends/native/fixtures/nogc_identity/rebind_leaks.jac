"""Owned string locals free what they hold: a module-level binding rebound in
a loop drops the value it replaces, and a function local bound from `str()`,
an f-string, a concatenation or a method result is freed at scope exit."""

def label(n: int) -> str {
    return f"item{n}";
}

def measure(i: int) -> int {
    a = str(label(i));
    b = f"at{i}";
    c = "ab" + b;
    d = c.upper();
    return len(a) + len(b) + len(c) + len(d);
}

with entry {
    total = 0;
    for i in range(50) {
        t = label(i);
        total += len(t) + measure(i);
    }
    print(t, total);
}
