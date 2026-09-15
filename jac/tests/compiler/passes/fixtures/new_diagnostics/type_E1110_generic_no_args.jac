"""Fixture for E1110: Generic type used without type parameters."""

with entry {
    x: list[any] = [1, 2, 3];  # <-- Error E1110: list[any] used without type params
    y: list[int] = [1, 2];  # <-- Ok
    z: dict[any, any] = {};  # <-- Error E1110: dict[any, any] used without type params
    w: dict[str, int] = {};  # <-- Ok
}
