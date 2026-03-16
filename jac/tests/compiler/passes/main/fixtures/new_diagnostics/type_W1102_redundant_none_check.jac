"""Fixture for W1102: Redundant None check."""

with entry {
    x: int = 5;
    if x is not None {  # <-- Warning W1102: x can never be None
        print(x);
    }
}
