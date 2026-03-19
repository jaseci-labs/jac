"""Fixture for W3023: if x: return True else: return False → return x."""

def bad(x: int) -> bool {
    if x > 0 {
        return True;   # <-- Warning W3023: simplify to 'return x > 0'
    } else {
        return False;
    }
}

def good(x: int) -> bool {
    return x > 0;  # <-- Ok
}
