"""Fixture: each `*_caller` uses the result of a call returning None as a value.

Native lowers that call to `void`, so the caller must refuse with E5092 (and
run on the server) instead of crashing or inventing a value (#7139).
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
