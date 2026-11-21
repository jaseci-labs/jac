"""Must fence (E1406): appending a borrowed string would alias the borrow."""
def stash(p: &str) -> int {
    xs = [];
    xs.append(p);
    return len(xs);
}

with entry {
    print(stash(&"hello"));
}
