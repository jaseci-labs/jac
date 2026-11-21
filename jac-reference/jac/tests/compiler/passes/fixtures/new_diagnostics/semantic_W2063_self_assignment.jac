"""Fixture for W2063: Self-assignment has no effect."""

with entry {
    x = 5;
    x = x;       # <-- Warning W2063: self-assignment
    y = 10;
    y = y + 1;   # <-- Ok: not a self-assignment
}
