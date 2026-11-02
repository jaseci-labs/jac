"""Fixture: a library declaring an unencodable enum that nothing reads."""

enum Unread { Half = 0.5, Whole = 1.0 }

def scaled(n: int) -> int {
    return n * 3;
}
