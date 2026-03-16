"""Fixture for W2070: Division by zero."""

with entry {
    x = 10 / 0;     # <-- Warning W2070
    y = 10 // 0;    # <-- Warning W2070
    z = 10 % 0;     # <-- Warning W2070
    w = 10 / 2;     # <-- Ok
}
