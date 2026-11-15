"""The defining half of the missing-import probe: two names, not three."""

glob present_table: list[int] = [1, 2, 3];

def present_fn(x: int) -> int {
    return x + 1;
}
