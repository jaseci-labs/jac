"""Fixture for E1110: Generic type used without type parameters."""

with entry {
    x: list = [1, 2, 3];    # <-- Error E1110: list used without type params
    y: list[int] = [1, 2];  # <-- Ok
    z: dict = {};            # <-- Error E1110: dict used without type params
    w: dict[str, int] = {};  # <-- Ok
}
