"""Fixture for E1150: Integer overflow."""

with entry {
    # Python ints are arbitrary precision, so this mainly applies to
    # typed contexts like native compilation or explicit fixed-width types
    x: int = 99999999999999999999999999;  # <-- Ok for Python
    # When targeting native (na) with fixed-width integers:
    # y: i32 = 2147483648;  # <-- Error E1150: exceeds i32 range
}
