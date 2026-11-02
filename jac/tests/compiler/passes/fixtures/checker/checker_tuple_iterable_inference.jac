"""Fixed tuple positions all contribute to the inherited iterable parameter,
and every member of a union iterable contributes to its element type."""

def union_iterables(spec: any, xs: list[int] | list[str]) -> int {
    total = 0;
    for p in (spec.get("ports", []) or []) {
        total += int(p.get("port", 0) or 0);
    }
    for x in xs {
        bad_union: int = x;
    }
    return total;
}

with entry {
    forward = list((1, "two"));
    reverse = list(("two", 1));
    bad_forward: int = forward[0];
    bad_reverse: str = reverse[0];
    homogeneous = list((1, 2));
    good: int = homogeneous[0];
    print(bad_forward, bad_reverse, good);
}
