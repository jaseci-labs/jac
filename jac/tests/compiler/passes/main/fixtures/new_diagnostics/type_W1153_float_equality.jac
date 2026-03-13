"""Fixture for W1153: Floating point equality comparison."""

with entry {
    x: float = 0.1 + 0.2;
    if x == 0.3 {          # <-- Warning W1153: float equality comparison
        print("equal");
    }

    if abs(x - 0.3) < 1e-9 {  # <-- Ok: approximate comparison
        print("close enough");
    }

    y: int = 5;
    if y == 5 {            # <-- Ok: integer comparison
        print("five");
    }
}
