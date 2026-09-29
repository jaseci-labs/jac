"""`str()` of a string hands back a value its consumer owns.

Under nogc, `str(s)` returned `s` itself. A consumer that frees the call's
result then freed a string it did not own: a static exception message bound
by `except IndexError as e` was freed by `print(str(e))` ("pointer being
freed was not allocated"), and so was a literal passed through `str()`. An
owned argument now passes through and anything else is copied."""

obj OutOfRange(IndexError) {}

def label(n: int) -> str {
    return f"item{n}";
}

def measure(i: int) -> int {
    t = label(i);
    return len(t) + len(str(t));
}

with entry {
    total = 0;
    for i in range(50) {
        total += measure(i);
    }
    try {
        raise OutOfRange("out of range");
    } except IndexError as e {
        print("caught:", str(e));
    }
    print(str("literal"), str(label(3)), total);
}
