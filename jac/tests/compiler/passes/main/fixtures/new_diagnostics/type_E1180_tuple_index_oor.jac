"""Fixture for E1180: Tuple index out of range."""

with entry {
    t: tuple[int, str, bool] = (1, "two", True);
    a = t[0];   # <-- Ok
    b = t[1];   # <-- Ok
    c = t[2];   # <-- Ok
    d = t[3];   # <-- Error E1180: index 3 out of range for 3-element tuple
    e = t[-1];  # <-- Ok: negative indexing
}
