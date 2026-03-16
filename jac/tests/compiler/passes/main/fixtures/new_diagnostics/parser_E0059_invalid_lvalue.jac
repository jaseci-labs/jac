"""Fixture for E0059: Assignment target is not a valid l-value."""

with entry {
    1 + 2 = x;          # <-- Error E0059
    "hello" = y;        # <-- Error E0059
    foo() = z;          # <-- Error E0059
    x = 5;              # <-- Ok
    a[0] = 1;           # <-- Ok
    a.b = 2;            # <-- Ok
}
