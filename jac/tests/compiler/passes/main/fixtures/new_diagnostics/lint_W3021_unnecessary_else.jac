"""Fixture for W3021: Unnecessary else after return/raise/break/continue."""

def bad(x: int) -> int {
    if x > 0 {
        return x;
    } else {             # <-- Warning W3021: unnecessary else after return
        return -x;
    }
}

def good(x: int) -> int {
    if x > 0 {
        return x;
    }
    return -x;  # <-- Ok: no else needed
}
