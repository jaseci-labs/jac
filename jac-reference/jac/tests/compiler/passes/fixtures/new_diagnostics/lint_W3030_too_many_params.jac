"""Fixture for W3030: Function has too many parameters."""

def too_many(a: int, b: int, c: int, d: int, e: int,
             f: int, g: int, h: int) -> int {
    # <-- Warning W3030: 8 parameters exceeds threshold
    return a + b + c + d + e + f + g + h;
}

def ok_count(a: int, b: int, c: int) -> int {  # <-- Ok
    return a + b + c;
}
