"""Scalar-typed reads off an owned root must not consume the owner:
`v = xs.pop()` copies an int out, and `len(xs)` in a loop header is not a
move (shared exempt list with _call_move_gen)."""

def drain -> int {
    xs: list[int] = [1, 2, 3];
    total = 0;
    while len(xs) > 0 {
        v = xs.pop();
        total += v;
    }
    xs.append(9);
    return total + len(xs);
}

with entry {
    print(drain());
}
