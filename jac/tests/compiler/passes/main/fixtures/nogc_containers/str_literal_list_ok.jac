"""Must stay clean: list of string literals (static, not owned heap)."""
def run -> int {
    xs = ["alpha", "beta"];
    xs.append("gamma");
    total = 0;
    for s in xs {
        total += len(s);
    }
    return total;
}

with entry {
    print(run());
}
