"""Fixture for W2062: Variable assigned but value never read before reassignment."""

with entry {
    x = 5;       # <-- Warning W2062: assigned but overwritten on next line
    x = 10;
    print(x);

    y = 1;       # <-- Ok: used before reassignment
    print(y);
    y = 2;
    print(y);
}
