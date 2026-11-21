with entry {
    # Properly-typed list: `some[0]` is `list[int]`, which has `__len__`,
    # so `len(some[0])` resolves cleanly without the bare-generic /
    # Any leak that strict mode rejects.
    some: list[list[int]] = [[1,2,3]];
    len(some[0]);  # <-- Ok
}
