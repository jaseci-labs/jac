"""Must-fail under --memory nogc: unannotated heap-typed parameter (E1401)."""

def helper(tmp: list[int]) -> int {
    return len(tmp);
}

with entry {
    print(helper([1, 2, 3]));
}
