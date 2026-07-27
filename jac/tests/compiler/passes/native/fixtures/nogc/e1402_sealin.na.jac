"""Must-fail under --enforce-nogc: owned value sealed into managed storage (E1402)."""

glob cache: list[list[int]] = [];

def stash -> int {
    data = [1, 2, 3];
    cache.append(data);
    return len(cache);
}

with entry {
    print(stash());
}
