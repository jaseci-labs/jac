"""Fixed tuple positions all contribute to the inherited iterable parameter."""
with entry {
    forward = list((1, "two"));
    reverse = list(("two", 1));
    bad_forward: int = forward[0];
    bad_reverse: str = reverse[0];
    homogeneous = list((1, 2));
    good: int = homogeneous[0];
    print(bad_forward, bad_reverse, good);
}
