"""Fixture for W1161: Unreachable match case."""

with entry {
    x: int = 5;

    match x {
        case _: print("catch all");
        case 5: print("five");  # <-- Warning W1161: unreachable after wildcard
    }
}
