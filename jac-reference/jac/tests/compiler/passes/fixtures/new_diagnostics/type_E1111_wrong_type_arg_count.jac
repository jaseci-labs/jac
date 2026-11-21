"""Fixture for E1111: Too many/few type arguments."""

with entry {
    x: dict[str] = {};             # <-- Error E1111: expected 2 type args, got 1
    y: dict[str, int, bool] = {};  # <-- Error E1111: expected 2 type args, got 3
    z: dict[str, int] = {};        # <-- Ok
    w: list[int, str] = [];        # <-- Error E1111: expected 1 type arg, got 2
}
