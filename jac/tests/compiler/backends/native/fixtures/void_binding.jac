"""Fixture: each `*_caller` uses the result of a call returning None as a value.

The caller must either refuse with E5092 or bind None; it must never crash
the compiler or invent a value (#7139).
"""

obj Sink {
    def annotated -> None {
        return;
    }
}

def sink(x: int) -> None {
    return;
}

def caller(x: int) -> int {
    y = sink(x);
    return x;
}

def method_caller(s: Sink) -> int {
    y = s.annotated();
    return 1;
}
